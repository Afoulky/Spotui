import SwiftUI

@main
struct MeloBridgeApp: App {
    @StateObject private var playback = LocalPlayback()
    @StateObject private var spotify = SpotifySession()

    var body: some Scene {
        WindowGroup {
            TabView {
                SpotifySearchView(session: spotify, playback: playback)
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
                LibraryView(playback: playback)
                    .tabItem { Label("Library", systemImage: "music.note.list") }
            }
                .preferredColorScheme(.dark)
                .tint(Color(red: 0.12, green: 0.84, blue: 0.38))
                .onOpenURL { url in
                    Task { await playback.importFiles([url]) }
                }
        }
    }
}
