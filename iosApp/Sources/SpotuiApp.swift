import SwiftUI

@main
struct SpotuiApp: App {
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
                .tint(SpotuiStyle.accent)
                .background(SpotuiStyle.background.ignoresSafeArea())
                .onOpenURL { url in
                    Task { await playback.importFiles([url]) }
                }
        }
    }
}
