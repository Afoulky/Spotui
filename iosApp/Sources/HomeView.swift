import SwiftUI

struct HomeView: View {
    @ObservedObject var session: SpotifySession
    @ObservedObject var playback: LocalPlayback
    @State private var showLogin = false
    @State private var resolver = AudioSourceResolver()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    filters
                    if session.isSignedIn {
                        playlistGrid
                        playlistShelf
                    } else {
                        loginState
                    }
                }
                .padding(.horizontal, 16).padding(.top, 18)
            }
            .background(MeloBridgeColors.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .task {
                if session.isSignedIn && session.playlists.isEmpty {
                    await session.loadPlaylists(reset: true)
                }
            }
            .sheet(isPresented: $showLogin) { SpotifyWebLogin(session: session) }
        }.navigationViewStyle(.stack)
    }

    private var filters: some View {
        HStack(spacing: 10) {
            Circle().fill(Color.orange).frame(width: 42, height: 42).overlay(Text("M").font(.headline).foregroundColor(.black))
            chip("All", selected: true)
            chip("Music")
            chip("Podcasts")
        }
    }

    private func chip(_ title: String, selected: Bool = false) -> some View {
        Text(title).font(.system(size: 14, weight: .medium)).foregroundColor(selected ? .black : .white)
            .padding(.horizontal, 18).frame(height: 38)
            .background(selected ? MeloBridgeColors.accent : MeloBridgeColors.surface)
            .clipShape(Capsule())
    }

    private var playlistGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(session.playlists.prefix(8)) { playlist in
                NavigationLink(destination: SpotifyPlaylistDetailView(
                    session: session, playback: playback, resolver: resolver, playlist: playlist
                )) {
                    HStack(spacing: 10) {
                        SpotifyArtwork(url: playlist.artworkURL, size: 52)
                        Text(playlist.name).font(.system(size: 13, weight: .bold)).foregroundColor(.white).lineLimit(2)
                        Spacer(minLength: 2)
                    }
                    .background(MeloBridgeColors.surface).clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var playlistShelf: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Made For You").font(.system(size: 26, weight: .bold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(session.playlists) { playlist in
                        NavigationLink(destination: SpotifyPlaylistDetailView(
                            session: session, playback: playback, resolver: resolver, playlist: playlist
                        )) {
                            VStack(alignment: .leading, spacing: 8) {
                                SpotifyArtwork(url: playlist.artworkURL, size: 150)
                                Text(playlist.name).font(.system(size: 15, weight: .bold)).foregroundColor(.white).lineLimit(1)
                                Text(playlist.owner.isEmpty ? "Playlist" : "Playlist · \(playlist.owner)")
                                    .font(.system(size: 13)).foregroundColor(MeloBridgeColors.secondary).lineLimit(1)
                            }.frame(width: 150, alignment: .leading)
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var loginState: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 80)
            Text("Spotify session expired or unauthenticated").font(.title3.bold()).multilineTextAlignment(.center)
            Text("Log in to load your personalized playlists, recommendations, and library.")
                .font(.subheadline).foregroundColor(.gray).multilineTextAlignment(.center)
            Button("Log in to Spotify") { showLogin = true }
                .font(.system(size: 14, weight: .bold)).foregroundColor(.black)
                .padding(.horizontal, 24).frame(height: 44).background(MeloBridgeColors.accent).clipShape(Capsule())
        }.frame(maxWidth: .infinity)
    }
}
