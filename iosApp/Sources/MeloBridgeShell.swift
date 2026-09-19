import SwiftUI

enum MeloBridgeColors {
    static let background = Color(red: 11.0 / 255.0, green: 11.0 / 255.0, blue: 15.0 / 255.0)
    static let surface = Color(red: 42.0 / 255.0, green: 42.0 / 255.0, blue: 42.0 / 255.0)
    static let accent = Color(red: 30.0 / 255.0, green: 215.0 / 255.0, blue: 96.0 / 255.0)
    static let secondary = Color(red: 179.0 / 255.0, green: 179.0 / 255.0, blue: 179.0 / 255.0)
}

private enum RootTab: CaseIterable, Hashable {
    case home, search, library

    var title: String {
        switch self {
        case .home: return "Home"
        case .search: return "Search"
        case .library: return "Library"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .search: return "magnifyingglass"
        case .library: return "books.vertical.fill"
        }
    }
}

struct MeloBridgeShell: View {
    @ObservedObject var session: SpotifySession
    @ObservedObject var playback: LocalPlayback
    @State private var selectedTab: RootTab = .home
    @State private var showPlayer = false

    var body: some View {
        ZStack(alignment: .bottom) {
            MeloBridgeColors.background.ignoresSafeArea()
            ZStack {
                HomeView(session: session, playback: playback)
                    .opacity(selectedTab == .home ? 1 : 0).allowsHitTesting(selectedTab == .home)
                SpotifySearchView(session: session, playback: playback)
                    .opacity(selectedTab == .search ? 1 : 0).allowsHitTesting(selectedTab == .search)
                LibraryView(playback: playback)
                    .opacity(selectedTab == .library ? 1 : 0).allowsHitTesting(selectedTab == .library)
            }
            .padding(.bottom, playbackTitle == nil ? 74 : 136)

            VStack(spacing: 0) {
                if let title = playbackTitle {
                    MiniPlayerView(
                        title: title,
                        subtitle: playbackSubtitle,
                        artworkURL: playback.currentRemote?.artworkURL,
                        isPlaying: playback.isPlaying,
                        progress: playbackProgress,
                        toggle: playback.toggle,
                        open: { showPlayer = true }
                    )
                    .padding(.horizontal, 13)
                }
                rootNavigation
            }
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.96), .black],
                    startPoint: .top, endPoint: .bottom
                ).ignoresSafeArea(edges: .bottom)
            )
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPlayer) {
            NowPlayingView(playback: playback)
        }
    }

    private var rootNavigation: some View {
        HStack {
            ForEach(RootTab.allCases, id: \.self) { tab in
                Button { selectedTab = tab } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.icon).font(.system(size: 24, weight: .semibold))
                        Text(tab.title).font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(selectedTab == tab ? .white : .gray)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 70)
        .padding(.horizontal, 22)
    }

    private var playbackTitle: String? {
        playback.currentRemote?.name ?? playback.current?.name
    }

    private var playbackSubtitle: String {
        playback.currentRemote?.artist ?? "On this device"
    }

    private var playbackProgress: Double {
        guard playback.duration > 0 else { return 0 }
        return min(max(playback.position / playback.duration, 0), 1)
    }
}

private struct MiniPlayerView: View {
    let title: String
    let subtitle: String
    let artworkURL: URL?
    let isPlaying: Bool
    let progress: Double
    let toggle: () -> Void
    let open: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                SpotifyArtwork(url: artworkURL, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 15, weight: .bold)).lineLimit(1)
                    Text(subtitle).font(.system(size: 13)).foregroundColor(.white.opacity(0.72)).lineLimit(1)
                }
                Spacer()
                Image(systemName: "plus.circle").font(.system(size: 27))
                Button(action: toggle) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 25)).frame(width: 38, height: 48)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            GeometryReader { proxy in
                Rectangle().fill(Color.white.opacity(0.28))
                    .overlay(alignment: .leading) {
                        Rectangle().fill(Color.white).frame(width: proxy.size.width * progress)
                    }
            }.frame(height: 2)
        }
        .frame(height: 64)
        .background(Color(red: 43.0 / 255.0, green: 34.0 / 255.0, blue: 91.0 / 255.0))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
    }
}

private struct NowPlayingView: View {
    @ObservedObject var playback: LocalPlayback
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 45.0 / 255.0, green: 35.0 / 255.0, blue: 92.0 / 255.0), .black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 26) {
                HStack {
                    Button { presentationMode.wrappedValue.dismiss() } label: {
                        Image(systemName: "chevron.down").font(.title2.bold())
                    }
                    Spacer()
                    Text("NOW PLAYING").font(.caption.bold())
                    Spacer()
                    Image(systemName: "ellipsis").font(.title2)
                }
                AsyncImage(url: playback.currentRemote?.artworkURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color.white.opacity(0.08)
                            .overlay(Image(systemName: "music.note").font(.system(size: 72)).foregroundColor(.white.opacity(0.7)))
                    }
                }
                .aspectRatio(1, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 5) {
                    Text(playback.currentRemote?.name ?? playback.current?.name ?? "")
                        .font(.title2.bold()).lineLimit(1)
                    Text(playback.currentRemote?.artist ?? "On this device")
                        .foregroundColor(MeloBridgeColors.secondary).lineLimit(1)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Slider(value: Binding(get: { playback.position }, set: playback.seek), in: 0...max(playback.duration, 1))
                    .tint(.white)
                HStack(spacing: 55) {
                    Button(action: playback.previous) { Image(systemName: "backward.end.fill") }
                    Button(action: playback.toggle) {
                        Image(systemName: playback.isPlaying ? "pause.circle.fill" : "play.circle.fill").font(.system(size: 64))
                    }
                    Button(action: playback.next) { Image(systemName: "forward.end.fill") }
                }.font(.title2)
            }.padding(24)
        }.preferredColorScheme(.dark)
    }
}
