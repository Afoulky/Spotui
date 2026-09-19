import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @ObservedObject var playback: LocalPlayback
    @State private var isImporting = false
    @State private var isCopying = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if playback.tracks.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 60)).foregroundStyle(.green)
                        Text("Your music on iPhone and iPad")
                            .font(.title2.bold()).multilineTextAlignment(.center)
                        Text("Import an audio file from Files to start listening.")
                            .foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Button("Import music") { isImporting = true }
                            .buttonStyle(.borderedProminent).disabled(isCopying)
                    }
                    .padding(32).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section("On this device") {
                            ForEach(playback.tracks, id: \.id) { track in
                                Button { playback.play(track) } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: playback.current?.id == track.id ? "speaker.wave.2.fill" : "music.note")
                                            .foregroundStyle(.green).frame(width: 28)
                                        Text(track.name).foregroundStyle(.primary).lineLimit(2)
                                        Spacer()
                                        Image(systemName: "play.circle").foregroundStyle(.secondary)
                                    }.padding(.vertical, 8)
                                }
                            }.onDelete(perform: playback.remove)
                        }
                        Section {
                            Text("Use the Spotify tab to search and browse playlists. Audio for those tracks is resolved through another provider.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }.listStyle(.insetGrouped)
                }
                if isCopying { ProgressView("Importing…").padding() }
                if let track = playback.current {
                    VStack(spacing: 12) {
                        Text(track.name).font(.headline).lineLimit(1)
                        Slider(
                            value: Binding(get: { min(playback.position, max(playback.duration, 1)) }, set: playback.seek),
                            in: 0...max(playback.duration, 1)
                        ).disabled(playback.duration <= 0)
                        HStack {
                            Text(time(playback.position))
                            Spacer()
                            Text(time(playback.duration))
                        }.font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        HStack(spacing: 40) {
                            Button(action: playback.previous) { Image(systemName: "backward.end.fill") }
                                .accessibilityLabel("Previous")
                            Button(action: playback.toggle) {
                                Image(systemName: playback.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 48))
                            }.accessibilityLabel(playback.isPlaying ? "Pause" : "Play")
                            Button(action: playback.next) { Image(systemName: "forward.end.fill") }
                                .accessibilityLabel("Next")
                        }.font(.title2)
                    }
                    .padding().frame(maxWidth: 700).background(.ultraThinMaterial)
                }
            }
            .navigationTitle("MeloBridge")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { isImporting = true } label: { Label("Import", systemImage: "plus") }
                        .disabled(isCopying)
                }
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls):
                    isCopying = true
                    Task {
                        await playback.importFiles(urls)
                        isCopying = false
                    }
                case .failure(let error): playback.errorMessage = error.localizedDescription
                }
            }
            .alert("MeloBridge", isPresented: Binding(
                get: { playback.errorMessage != nil },
                set: { if !$0 { playback.errorMessage = nil } }
            )) {
                Button("OK") { playback.errorMessage = nil }
            } message: { Text(playback.errorMessage ?? "") }
        }
        // Keep a single-column layout on iPad while supporting iOS 15.
        .navigationViewStyle(.stack)
    }

    private func time(_ seconds: Double) -> String {
        let value = Int(max(0, seconds))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}
