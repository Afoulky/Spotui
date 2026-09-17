import SwiftUI

struct SpotifySearchView: View {
    @ObservedObject var session: SpotifySession
    @State private var query = ""
    @State private var showLogin = false

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
