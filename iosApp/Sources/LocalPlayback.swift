import AVFoundation
import Combine
import MediaPlayer
import SpotuiShared

/// App-scoped native audio adapter, owned by SpotuiApp.
/// Track metadata uses the same Kotlin model as the Android application.
@MainActor
final class LocalPlayback: ObservableObject {
    @Published private(set) var tracks: [SpotifyTrack] = []
    @Published private(set) var current: SpotifyTrack?
    @Published private(set) var currentRemote: SpotifySearchTrack?
    @Published private(set) var isPlaying = false
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    @Published var errorMessage: String?

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var playbackObserver: NSKeyValueObservation?
    private var notifications: [NSObjectProtocol] = []
    private var resumeAfterInterruption = false
    // AVPlayer may already be paused when an interruption notification arrives.
    private var playbackRequested = false

    init() {
        reloadLibrary()
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.position = time.seconds.isFinite ? max(0, time.seconds) : 0
                let seconds = self.player.currentItem?.duration.seconds ?? 0
                self.duration = seconds.isFinite ? max(0, seconds) : 0
                self.updateNowPlaying()
            }
        }
        // Observe the actual player state so buffering does not appear as active playback.
        playbackObserver = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isPlaying = self.player.timeControlStatus == .playing
                self.updateNowPlaying()
            }
        }
        notifications.append(NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main
        ) { [weak self] notification in
            guard let item = notification.object as? AVPlayerItem else { return }
            Task { @MainActor [weak self] in
                guard let self, item === self.player.currentItem else { return }
                self.next()
            }
        })
        notifications.append(NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let options = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            Task { @MainActor [weak self] in
                guard let self else { return }
                if type == AVAudioSession.InterruptionType.began.rawValue {
                    let shouldResume = self.playbackRequested
                    self.pause()
                    self.resumeAfterInterruption = shouldResume
                } else if type == AVAudioSession.InterruptionType.ended.rawValue {
                    if self.resumeAfterInterruption && AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume) {
                        self.resume()
                    }
                    self.resumeAfterInterruption = false
                }
            }
        })
        notifications.append(NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
                Task { @MainActor [weak self] in self?.pause() }
            }
        })
        installRemoteCommands()
    }

    private func libraryDirectory() throws -> URL {
        let documents = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let directory = documents.appendingPathComponent("Music", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func reloadLibrary() {
        do {
            let root = try libraryDirectory()
            // Only scan the per-import directories; ignore metadata and stray files.
            let directories = try FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            ).filter {
                let values = try $0.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                return values.isDirectory == true && values.isSymbolicLink != true
            }
            let files = try directories.flatMap {
                try FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
            }
            tracks = try files.filter { try $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true }
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
                .map { LocalTracks.shared.fromFile(fileName: $0.lastPathComponent, uri: $0.absoluteString) }
        } catch {
            errorMessage = "Unable to load the library: \(error.localizedDescription)"
        }
    }

    func importFiles(_ urls: [URL]) async {
        // Copy outside the main thread; cloud-hosted files may need downloading.
        do {
            let root = try libraryDirectory()
            let failures = await Task.detached(priority: .userInitiated) {
                var failures: [String] = []
                for source in urls {
                    let access = source.startAccessingSecurityScopedResource()
                    defer {
                        if access {
                            source.stopAccessingSecurityScopedResource()
                        }
                    }
                    // Separate folders preserve filenames without collisions between imports.
                    let folder = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
                    do {
                        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                        var coordinationError: NSError?
                        var copyError: Error?
                        // File providers may need to materialize a cloud file before it can be copied.
                        NSFileCoordinator().coordinate(readingItemAt: source, options: [], error: &coordinationError) { readable in
                            do {
                                try FileManager.default.copyItem(at: readable, to: folder.appendingPathComponent(source.lastPathComponent))
                            } catch {
                                copyError = error
                            }
                        }
                        if let error = coordinationError ?? (copyError as NSError?) {
                            throw error
                        }
                    } catch {
                        try? FileManager.default.removeItem(at: folder)
                        failures.append(source.lastPathComponent)
                    }
                }
                return failures
            }.value
            reloadLibrary()
            if !failures.isEmpty {
                errorMessage = "Unable to import: " + failures.joined(separator: ", ")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func play(_ track: SpotifyTrack) {
        guard let uri = track.uri, let url = URL(string: uri), url.isFileURL else { return }
        current = track
        currentRemote = nil
        replaceItem(with: url)
    }

    func playRemote(_ track: SpotifySearchTrack, from url: URL) {
        current = nil
        currentRemote = track
        replaceItem(with: url)
    }

    func stopRemote() {
        guard currentRemote != nil else { return }
        pause()
        player.replaceCurrentItem(with: nil)
        currentRemote = nil
        position = 0
        duration = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func replaceItem(with url: URL) {
        position = 0
        duration = 0
        let item = AVPlayerItem(url: url)
        statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self, item === self.player.currentItem, item.status == .failed else { return }
                self.errorMessage = item.error?.localizedDescription ?? "This audio file could not be played."
                self.pause()
            }
        }
        player.replaceCurrentItem(with: item)
        resume()
    }

    func resume() {
        guard current != nil || currentRemote != nil else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            let end = player.currentItem?.duration.seconds ?? 0
            if end.isFinite && end > 0 && player.currentTime().seconds >= end {
                player.seek(to: .zero)
            }
            playbackRequested = true
            player.play()
            updateNowPlaying()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func pause() {
        playbackRequested = false
        resumeAfterInterruption = false
        player.pause()
        updateNowPlaying()
    }

    func toggle() {
        if player.timeControlStatus == .paused {
            resume()
        } else {
            pause()
        }
    }

    func seek(to seconds: Double) {
        guard seconds.isFinite else { return }
        player.seek(to: CMTime(seconds: max(0, min(seconds, duration)), preferredTimescale: 600))
    }

    func next() {
        if currentRemote != nil { pause(); return }
        guard let index = tracks.firstIndex(where: { $0.id == current?.id }) else { return }
        if index + 1 < tracks.count {
            play(tracks[index + 1])
        } else {
            pause()
        }
    }

    func previous() {
        if currentRemote != nil { seek(to: 0); return }
        guard let index = tracks.firstIndex(where: { $0.id == current?.id }) else { return }
        if position > 3 || index == 0 {
            seek(to: 0)
        } else {
            play(tracks[index - 1])
        }
    }

    func remove(at offsets: IndexSet) {
        for index in offsets {
            let track = tracks[index]
            guard let uri = track.uri, let url = URL(string: uri) else { continue }
            do {
                try FileManager.default.removeItem(at: url.deletingLastPathComponent())
                if current?.id == track.id {
                    pause()
                    player.replaceCurrentItem(with: nil)
                    current = nil
                    position = 0
                    duration = 0
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        reloadLibrary()
    }

    private func updateNowPlaying() {
        guard current != nil || currentRemote != nil else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: currentRemote?.name ?? current?.name ?? "",
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
            MPNowPlayingInfoPropertyPlaybackRate: player.rate
        ]
        if let artist = currentRemote?.artist { info[MPMediaItemPropertyArtist] = artist }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func installRemoteCommands() {
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.resume() }
            return .success
        }
        commands.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.pause() }
            return .success
        }
        commands.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.next() }
            return .success
        }
        commands.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.previous() }
            return .success
        }
        commands.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let seconds = event.positionTime
            Task { @MainActor [weak self] in self?.seek(to: seconds) }
            return .success
        }
    }
}
