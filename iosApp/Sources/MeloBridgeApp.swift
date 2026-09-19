import SwiftUI

@main
struct MeloBridgeApp: App {
    @StateObject private var playback = LocalPlayback()
    @StateObject private var spotify = SpotifySession()

    var body: some Scene {
        WindowGroup {
            MeloBridgeShell(session: spotify, playback: playback)
                .onOpenURL { url in
                    Task { await playback.importFiles([url]) }
                }
        }
    }
}
