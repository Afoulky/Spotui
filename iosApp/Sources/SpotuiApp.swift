import SwiftUI

@main
struct SpotuiApp: App {
    @StateObject private var playback = LocalPlayback()
    @StateObject private var spotify = SpotifySession()

    var body: some Scene {
        WindowGroup {
            TabView {
                LibraryView(playback: playback)
                    .tabItem { Label("Local", systemImage: "music.note.list") }
                SpotifySearchView(session: spotify, playback: playback)
                    .tabItem { Label("Spotify", systemImage: "magnifyingglass") }
            }
                .preferredColorScheme(.dark)
                .tint(Color(red: 0.12, green: 0.84, blue: 0.38))
                .onOpenURL { url in
                    Task { await playback.importFiles([url]) }
                }
        }
    }
}
