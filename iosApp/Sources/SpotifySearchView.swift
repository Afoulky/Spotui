import SwiftUI

struct SpotifySearchView: View {
    @ObservedObject var session: SpotifySession
    @ObservedObject var playback: LocalPlayback
    @State private var query = ""
    @State private var showLogin = false
    @State private var isResolving = false
    @State private var resolver = AudioSourceResolver()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack {
                    Text("Search").font(.system(size: 30, weight: .bold))
                    Spacer()
                    if session.isSignedIn {
                        Menu {
                            Button("Sign out", role: .destructive) {
                                playback.stopRemote()
                                session.signOut()
                            }
                        } label: {
                            Image(systemName: "person.crop.circle.fill").font(.system(size: 32)).foregroundColor(.orange)
                        }
                    }
                }.padding(.horizontal, 16).padding(.top, 18).padding(.bottom, 12)
                if !session.isSignedIn {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 52)).foregroundColor(MeloBridgeColors.accent)
                        Text("Search Spotify")
                            .font(.title2.bold())
                        Text("Sign in to explore tracks from your Spotify account.")
                            .multilineTextAlignment(.center).foregroundColor(.secondary)
                        Button("Sign in to Spotify") { showLogin = true }
                            .font(.system(size: 14, weight: .bold)).foregroundColor(.black)
                            .padding(.horizontal, 24).frame(height: 44)
                            .background(MeloBridgeColors.accent).clipShape(Capsule())
                    }
                    .padding(30).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundColor(.black)
                        TextField("What do you want to listen to?", text: $query)
                            .foregroundColor(.black).accentColor(.black)
                            .submitLabel(.search).onSubmit(runSearch)
                        if !query.isEmpty {
                            Button { query = ""; session.clearSearch() } label: {
                                Image(systemName: "xmark").foregroundColor(.black)
                            }
                        }
                    }
                    .padding(.horizontal, 14).frame(height: 48).background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 5)).padding(.horizontal, 16).padding(.bottom, 10)
                    if session.isBusy { ProgressView().tint(.white).padding() }
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(session.results) { track in
                                Button { play(track) } label: {
                                    HStack(spacing: 12) {
                                        SpotifyArtwork(url: track.artworkURL, size: 54)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(track.name).font(.system(size: 15, weight: .semibold)).foregroundColor(.white).lineLimit(1)
                                            Text(track.artist).font(.system(size: 13)).foregroundColor(MeloBridgeColors.secondary).lineLimit(1)
                                        }
                                        Spacer()
                                        Image(systemName: "ellipsis").foregroundColor(.gray)
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 6)
                                }.buttonStyle(.plain).disabled(isResolving)
                            }
                        }
                    }
                }
                if isResolving { ProgressView("Finding audio…").padding() }
            }
            .background(MeloBridgeColors.background.ignoresSafeArea())
            .navigationBarHidden(true)
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
        .onChange(of: session.isSignedIn) { signedIn in
            if !signedIn { playback.stopRemote() }
        }
    }

    private func runSearch() {
        Task { await session.search(query) }
    }

    private func play(_ track: SpotifySearchTrack) {
        guard !isResolving else { return }
        let revision = session.revision
        isResolving = true
        Task {
            defer { isResolving = false }
            do {
                let source = try await resolver.resolve(track)
                guard session.isSignedIn, revision == session.revision else { return }
                playback.playRemote(track, from: source)
            } catch {
                if revision == session.revision { session.errorMessage = error.localizedDescription }
            }
        }
    }
}

struct SpotifyArtwork: View {
    let url: URL?
    let size: CGFloat

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                MeloBridgeColors.surface.overlay(Image(systemName: "music.note").foregroundColor(.gray))
            }
        }
        .frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

private struct SpotifyPlaylistsView: View {
    @ObservedObject var session: SpotifySession
    @ObservedObject var playback: LocalPlayback
    let resolver: AudioSourceResolver
    @State private var deferredInitialLoad = false

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
        .task {
            if session.isBusy {
                deferredInitialLoad = true
            } else {
                await session.loadPlaylists(reset: true)
            }
        }
        .onChange(of: session.isBusy) { busy in
            // The first load may have been skipped while a search was finishing.
            if !busy && deferredInitialLoad {
                deferredInitialLoad = false
                Task { await session.loadPlaylists(reset: true) }
            }
        }
    }
}

struct SpotifyPlaylistDetailView: View {
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
                    HStack(spacing: 12) {
                        SpotifyArtwork(url: track.artworkURL, size: 52)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(track.name).font(.headline)
                            Text(track.artist).font(.subheadline).foregroundColor(.secondary)
                            if !track.album.isEmpty {
                                Text(track.album).font(.caption).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "ellipsis").foregroundColor(.gray)
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
        .overlay { if isLoading || isResolving { ProgressView() } }
        .task { await loadTracks() }
        .alert("Playback", isPresented: Binding(
            get: { playbackErrorMessage != nil || playback.errorMessage != nil },
            set: {
                if !$0 {
                    playbackErrorMessage = nil
                    playback.errorMessage = nil
                }
            }
        )) {
            Button("OK") {
                playbackErrorMessage = nil
                playback.errorMessage = nil
            }
        } message: { Text(playbackErrorMessage ?? playback.errorMessage ?? "") }
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
        let revision = session.revision
        isResolving = true
        Task {
            defer { isResolving = false }
            do {
                let source = try await resolver.resolve(track)
                guard session.isSignedIn, revision == session.revision else { return }
                playback.playRemote(track, from: source)
            } catch {
                if revision == session.revision { playbackErrorMessage = error.localizedDescription }
            }
        }
    }
}
