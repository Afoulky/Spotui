import SwiftUI

struct SpotifySearchView: View {
    @ObservedObject var session: SpotifySession
    @State private var query = ""
    @State private var showLogin = false
    @State private var selectedSection = 0

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
                        SpotifyPlaylistsView(session: session)
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
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(track.name).font(.headline)
                                    Text(track.artist).font(.subheadline).foregroundColor(.secondary)
                                    if !track.album.isEmpty {
                                        Text(track.album).font(.caption).foregroundColor(.secondary)
                                    }
                                }.padding(.vertical, 4)
                            }
                            if !session.results.isEmpty {
                                Text("Spotify track playback is not available in this iOS milestone.")
                                    .font(.footnote).foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Spotify")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Sign out") { session.signOut() }
                        .disabled(!session.isSignedIn)
                }
            }
            .sheet(isPresented: $showLogin) { SpotifyWebLogin(session: session) }
            .alert("Spotify", isPresented: Binding(
                get: { session.errorMessage != nil && !showLogin },
                set: { if !$0 { session.errorMessage = nil } }
            )) {
                Button("OK") { session.errorMessage = nil }
            } message: { Text(session.errorMessage ?? "") }
        }
        .navigationViewStyle(.stack)
    }

    private func runSearch() {
        Task { await session.search(query) }
    }
}

private struct SpotifyPlaylistsView: View {
    @ObservedObject var session: SpotifySession

    var body: some View {
        List {
            ForEach(session.playlists) { playlist in
                NavigationLink(destination: SpotifyPlaylistDetailView(session: session, playlist: playlist)) {
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
    let playlist: SpotifyPlaylist
    @State private var tracks: [SpotifySearchTrack] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var nextOffset = 0
    @State private var totalTracks = 0

    var body: some View {
        List {
            ForEach(tracks.indices, id: \.self) { index in
                let track = tracks[index]
                VStack(alignment: .leading, spacing: 3) {
                    Text(track.name).font(.headline)
                    Text(track.artist).font(.subheadline).foregroundColor(.secondary)
                    if !track.album.isEmpty {
                        Text(track.album).font(.caption).foregroundColor(.secondary)
                    }
                }
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
            } else if !tracks.isEmpty {
                Text("Spotify playback is not available yet.")
                    .font(.footnote).foregroundColor(.secondary)
            }
        }
        .navigationTitle(playlist.name)
        .overlay { if isLoading { ProgressView() } }
        .task { await loadTracks() }
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
}
