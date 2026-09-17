import SwiftUI
import WebKit

struct SpotifyWebLogin: View {
    @ObservedObject var session: SpotifySession
    @Environment(\.dismiss) private var dismiss
    @State private var manualCookie = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                SpotifyLoginBrowser { cookie in
                    Task { await session.signIn(spDc: cookie) }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("If web sign-in cannot complete, paste your sp_dc cookie.")
                        .font(.footnote).foregroundColor(.secondary)
                    SecureField("sp_dc cookie", text: $manualCookie)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    Button("Use cookie") {
                        Task { await session.signIn(spDc: manualCookie) }
                    }
                    .disabled(session.isBusy || manualCookie.isEmpty)
                }
                .padding()
            }
            .navigationTitle("Spotify sign-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onChange(of: session.isSignedIn) { signedIn in
                if signedIn {
                    manualCookie = ""
                    dismiss()
                }
            }
            .alert("Spotify", isPresented: Binding(
                get: { session.errorMessage != nil },
                set: { if !$0 { session.errorMessage = nil } }
            )) {
                Button("OK") { session.errorMessage = nil }
            } message: { Text(session.errorMessage ?? "") }
        }
        .navigationViewStyle(.stack)
    }
}

private struct SpotifyLoginBrowser: UIViewRepresentable {
    let onCookie: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCookie: onCookie) }

    func makeUIView(context: Context) -> WKWebView {
        // Keep each login attempt isolated from earlier Spotify web sessions.
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.load(URLRequest(url: URL(string: "https://accounts.spotify.com/en/login")!))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let onCookie: (String) -> Void
        private var lastCookie: String?

        init(onCookie: @escaping (String) -> Void) { self.onCookie = onCookie }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self,
                      let cookie = cookies.first(where: {
                          $0.name == "sp_dc" && $0.domain.hasSuffix("spotify.com")
                      })?.value,
                      cookie != self.lastCookie else { return }
                self.lastCookie = cookie
                DispatchQueue.main.async { self.onCookie(cookie) }
            }
        }
    }
}
