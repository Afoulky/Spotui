import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct LibraryView: View {
    @ObservedObject var playback: LocalPlayback
    @State private var isImporting = false
    @State private var isCopying = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Circle().fill(Color.orange).frame(width: 38, height: 38)
                        .overlay(Text("M").font(.headline).foregroundColor(.black))
                    Text("Your Library").font(.system(size: 26, weight: .bold))
                    Spacer()
                    Image(systemName: "magnifyingglass").font(.system(size: 22))
                    Button { isImporting = true } label: {
                        Image(systemName: "plus").font(.system(size: 24))
                    }.buttonStyle(.plain).disabled(isCopying)
                }.padding(.horizontal, 16).padding(.top, 18).padding(.bottom, 12)
                HStack(spacing: 8) {
                    libraryChip("Playlists")
                    libraryChip("Downloaded")
                    libraryChip("Local files")
                }
                .padding(.horizontal, 16).frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)
                if playback.tracks.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 60)).foregroundStyle(MeloBridgeColors.accent)
                        Text("Your music on iPhone and iPad")
                            .font(.title2.bold()).multilineTextAlignment(.center)
                        Text("Import an audio file from Files to start listening.")
                            .foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Button("Import music") { isImporting = true }
                            .font(.system(size: 14, weight: .bold)).foregroundColor(.black)
                            .padding(.horizontal, 24).frame(height: 44)
                            .background(MeloBridgeColors.accent).clipShape(Capsule()).disabled(isCopying)
                    }
                    .padding(32).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section("On this device") {
                            ForEach(playback.tracks, id: \.id) { track in
                                Button { playback.play(track) } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: playback.current?.id == track.id ? "speaker.wave.2.fill" : "music.note")
                                            .foregroundStyle(MeloBridgeColors.accent).frame(width: 28)
                                        Text(track.name).foregroundStyle(.primary).lineLimit(2)
                                        Spacer()
                                        Image(systemName: "play.circle").foregroundStyle(.secondary)
                                    }.padding(.vertical, 8)
                                }
                            }.onDelete(perform: playback.remove)
                        }
                        Section {
                            Text("Use the Spotify tab to search and browse playlists. Audio for those tracks is resolved through another provider.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .listStyle(.plain)
                    .onAppear { UITableView.appearance().backgroundColor = .clear }
                }
                if isCopying { ProgressView("Importing…").padding() }
            }
            .background(MeloBridgeColors.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls):
                    isCopying = true
                    Task {
                        await playback.importFiles(urls)
                        isCopying = false
                    }
                case .failure(let error): playback.errorMessage = error.localizedDescription
                }
            }
            .alert("MeloBridge", isPresented: Binding(
                get: { playback.errorMessage != nil },
                set: { if !$0 { playback.errorMessage = nil } }
            )) {
                Button("OK") { playback.errorMessage = nil }
            } message: { Text(playback.errorMessage ?? "") }
        }
        // Keep a single-column layout on iPad while supporting iOS 15.
        .navigationViewStyle(.stack)
    }

    private func libraryChip(_ title: String) -> some View {
        Text(title).font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 14).frame(height: 34)
            .background(MeloBridgeColors.surface).clipShape(Capsule())
    }

}
