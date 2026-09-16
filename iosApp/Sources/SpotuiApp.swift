import SwiftUI

@main
struct SpotuiApp: App {
    @StateObject private var playback = LocalPlayback()

    var body: some Scene {
        WindowGroup {
            LibraryView(playback: playback)
                .preferredColorScheme(.dark)
                .tint(Color(red: 0.12, green: 0.84, blue: 0.38))
        }
    }
}
