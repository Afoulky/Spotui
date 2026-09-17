import SwiftUI

struct SpotifySearchView: View {
    @ObservedObject var session: SpotifySession
    @ObservedObject var playback: LocalPlayback
    @State private var query = ""
    @State private var showLogin = false
    @State private var selectedSection = 0
    @State private var isResolving = false
    @State private var resolver = AudioSourceResolver()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if !session.isSignedIn {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 52)).foregroundColor(.green)
                        Text("Search Spotify")
                            .font(.title2.bold())
                        Text("Sign in to explore tracks from your Spotify account.")
                            .multilineTextAlignment(.center).foregroundColor(.secondary)
                        Button("Sign in to Spotify") { showLogin = true }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(30).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Picker("Spotify section", selection: $selectedSection) {
                        Text("Search").tag(0)
                        Text("Playlists").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    if selectedSection == 1 {
                        SpotifyPlaylistsView(session: session, playback: playback, resolver: resolver)
                    } else {
                        HStack {
                            TextField("Songs or artists", text: $query)
                                .textFieldStyle(.roundedBorder)
                                .submitLabel(.search)
                                .onSubmit(runSearch)
                            Button("Search", action: runSearch)
                                .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || session.isBusy)
                        }.padding()
                        if session.isBusy { ProgressView().padding() }
                        List {
                            ForEach(session.results) { track in
                                Button { play(track) } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(track.name).font(.headline)
                                        Text(track.artist).font(.subheadline).foregroundColor(.secondary)
                                        if !track.album.isEmpty {
                                            Text(track.album).font(.caption).foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .disabled(isResolving)
                            }
                        }
                    }
                }
                if isResolving { ProgressView("Finding audio…").padding() }
                if let track = playback.currentRemote {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(track.name).font(.headline).lineLimit(1)
                            Text("\(track.artist) · \(playback.currentProvider ?? "")")
                                .font(.caption).foregroundColor(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Button(action: playback.toggle) {
                            Image(systemName: playback.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.title)
                        }
                    }
                    .padding().background(.ultraThinMaterial)
                }
            }
            .navigationTitle("Spotify")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Sign out") {
                        playback.stopRemote()
                        session.signOut()
                    }
                        .disabled(!session.isSignedIn)
                }
            }
            .sheet(isPresented: $showLogin) { SpotifyWebLogin(session: session) }
            .alert("Spotify", isPresented: Binding(
                get: { (session.errorMessage != nil || playback.errorMessage != nil) && !showLogin },
                set: {
                    if !$0 {
                        session.errorMessage = nil
                        playback.errorMessage = nil
                    }
                }
            )) {
                Button("OK") {
                    session.errorMessage = nil
                    playback.errorMessage = nil
                }
            } message: { Text(session.errorMessage ?? playback.errorMessage ?? "") }
        }
        .navigationViewStyle(.stack)
    }

    private func runSearch() {
        Task { await session.search(query) }
    }

    private func play(_ track: SpotifySearchTrack) {
        guard !isResolving else { return }
        isResolving = true
        Task {
            defer { isResolving = false }
            do {
                let source = try await resolver.resolve(track)
                playback.playRemote(track, from: source)
            } catch {
                session.errorMessage = error.localizedDescription
            }
        }
    }
}

private struct SpotifyPlaylistsView: View {
    @ObservedObject var session: SpotifySession
    @ObservedObject var playback: LocalPlayback
    let resolver: AudioSourceResolver

    var body: some View {
        List {
            ForEach(session.playlists) { playlist in
                NavigationLink(destination: SpotifyPlaylistDetailView(
                    session: session, playback: playback, resolver: resolver, playlist: playlist
                )) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(playlist.name).font(.headline)
                        if !playlist.owner.isEmpty {
                            Text(playlist.owner).font(.subheadline).foregroundColor(.secondary)
                        }
                    }
                }
            }
            if session.hasMorePlaylists {
                Button("Load more playlists") {
                    Task { await session.loadPlaylists() }
                }
                .disabled(session.isBusy)
            }
            if session.playlists.isEmpty && !session.isBusy {
                Text("No playlists found.").foregroundColor(.secondary)
            }
        }
        .overlay {
            if session.isBusy && session.playlists.isEmpty { ProgressView() }
        }
        .refreshable { await session.loadPlaylists(reset: true) }
        .task { await session.loadPlaylists(reset: true) }
    }
}

private struct SpotifyPlaylistDetailView: View {
    @ObservedObject var session: SpotifySession
    @ObservedObject var playback: LocalPlayback
    let resolver: AudioSourceResolver
    let playlist: SpotifyPlaylist
    @State private var tracks: [SpotifySearchTrack] = []
    @State private var errorMessage: String?
    @State private var playbackErrorMessage: String?
    @State private var isLoading = false
    @State private var nextOffset = 0
    @State private var totalTracks = 0
    @State private var isResolving = false

    var body: some View {
        List {
            ForEach(tracks.indices, id: \.self) { index in
                let track = tracks[index]
                Button { play(track) } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.name).font(.headline)
                        Text(track.artist).font(.subheadline).foregroundColor(.secondary)
                        if !track.album.isEmpty {
                            Text(track.album).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                .disabled(isResolving)
            }
            if nextOffset < totalTracks && errorMessage == nil {
                Button("Load more tracks") {
                    Task { await loadTracks() }
                }
                .disabled(isLoading)
            }
            if let errorMessage {
                Text(errorMessage).foregroundColor(.red)
                Button("Retry") { Task { await loadTracks() } }
                    .disabled(isLoading)
            } else if !isLoading && tracks.isEmpty {
                Text("No tracks found.").foregroundColor(.secondary)
            }
        }
        .navigationTitle(playlist.name)
        .safeAreaInset(edge: .bottom) {
            if let current = playback.currentRemote {
                HStack {
                    VStack(alignment: .leading) {
                        Text(current.name).lineLimit(1)
                        Text(playback.currentProvider ?? "")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: playback.toggle) {
                        Image(systemName: playback.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title)
                    }
                }
                .padding().background(.ultraThinMaterial)
            }
        }
        .overlay { if isLoading || isResolving { ProgressView() } }
        .task { await loadTracks() }
        .alert("Playback", isPresented: Binding(
            get: { playbackErrorMessage != nil },
            set: { if !$0 { playbackErrorMessage = nil } }
        )) {
            Button("OK") { playbackErrorMessage = nil }
        } message: { Text(playbackErrorMessage ?? "") }
    }

    private func loadTracks() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await session.tracks(in: playlist, offset: nextOffset)
            tracks.append(contentsOf: page.tracks)
            nextOffset += page.receivedCount
            totalTracks = page.receivedCount == 0 ? nextOffset : page.total
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func play(_ track: SpotifySearchTrack) {
        guard !isResolving else { return }
        isResolving = true
        Task {
            defer { isResolving = false }
            do {
                let source = try await resolver.resolve(track)
                playback.playRemote(track, from: source)
            } catch {
                playbackErrorMessage = error.localizedDescription
            }
        }
    }
}
