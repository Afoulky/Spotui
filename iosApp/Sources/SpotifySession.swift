import Combine
import CryptoKit
import Foundation
import Security
import WebKit

struct SpotifySearchTrack: Identifiable {
    let id: String
    let name: String
    let artist: String
    let album: String
}

struct SpotifyPlaylist: Identifiable {
    let id: String
    let name: String
    let owner: String
}

struct SpotifyPlaylistTrackPage {
    let tracks: [SpotifySearchTrack]
    let total: Int
    let receivedCount: Int
}

private enum SpotifyRequestError: LocalizedError {
    case invalidResponse(String)
    case http(Int)
    case expiredSession

    var errorDescription: String? {
        switch self {
        case .invalidResponse(let detail): return "Unexpected Spotify response: \(detail)"
        case .http(let status): return "Spotify request failed (HTTP \(status))."
        case .expiredSession: return "Your Spotify session has expired. Please sign in again."
        }
    }
}

/// Keeps the web session cookie in Keychain; bearer tokens remain in memory only.
@MainActor
final class SpotifySession: ObservableObject {
    @Published private(set) var isSignedIn = false
    @Published private(set) var isBusy = false
    @Published private(set) var results: [SpotifySearchTrack] = []
    @Published private(set) var playlists: [SpotifyPlaylist] = []
    @Published private(set) var hasMorePlaylists = false
    @Published var errorMessage: String?
    var revision: Int { sessionGeneration }

    private static let keychainService = "com.music.spotui.ios.spotify"
    private static let searchHash = "4801118d4a100f756e833d33984436a3899cff359c532f8fd3aaf174b60b3b49"
    private static let libraryHash = "973e511ca44261fda7eebac8b653155e7caee3675abb4fb110cc1b8c78b091c3"
    private static let playlistHash = "346811f856fb0b7e4f6c59f8ebea78dd081c6e2fb01b77c954b26259d5fc6763"
    private static let desktopUserAgent =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
    private var cookie: String?
    private var accessToken: String?
    private var tokenExpiresAt = Date.distantPast
    private var playlistOffset = 0
    private var sessionGeneration = 0

    init() {
        cookie = Self.readCookie()
        isSignedIn = cookie != nil
    }

    func signIn(spDc: String) async {
        let candidate = spDc.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else {
            errorMessage = "Enter a Spotify session cookie."
            return
        }
        guard !isBusy else { return }
        let generation = sessionGeneration
        isBusy = true
        defer { if generation == sessionGeneration { isBusy = false } }
        do {
            let token = try await Self.fetchToken(cookie: candidate)
            guard generation == sessionGeneration else { return }
            try Self.saveCookie(candidate)
            cookie = candidate
            accessToken = token.value
            tokenExpiresAt = token.expiresAt
            isSignedIn = true
            errorMessage = nil
        } catch {
            if generation == sessionGeneration { errorMessage = error.localizedDescription }
        }
    }

    func signOut() {
        sessionGeneration += 1
        Self.deleteCookie()
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            for cookie in cookies where cookie.domain.hasSuffix("spotify.com")
                && (cookie.name == "sp_dc" || cookie.name == "sp_key") {
                WKWebsiteDataStore.default().httpCookieStore.delete(cookie)
            }
        }
        cookie = nil
        accessToken = nil
        tokenExpiresAt = .distantPast
        results = []
        playlists = []
        hasMorePlaylists = false
        playlistOffset = 0
        isBusy = false
        isSignedIn = false
        errorMessage = nil
    }

    func search(_ query: String) async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            results = []
            return
        }
        guard cookie != nil, !isBusy else { return }
        let generation = sessionGeneration
        isBusy = true
        defer { if generation == sessionGeneration { isBusy = false } }
        do {
            let token = try await validToken()
            let found = try await Self.searchTracks(term, token: token)
            guard generation == sessionGeneration else { return }
            results = found
            errorMessage = nil
        } catch {
            if generation == sessionGeneration { handleRequestError(error) }
        }
    }

    func loadPlaylists(reset: Bool = false) async {
        guard cookie != nil, !isBusy else { return }
        if !reset && !playlists.isEmpty && !hasMorePlaylists { return }
        let generation = sessionGeneration
        isBusy = true
        defer { if generation == sessionGeneration { isBusy = false } }
        do {
            let token = try await validToken()
            let offset = reset ? 0 : playlistOffset
            let page = try await Self.fetchPlaylists(token: token, offset: offset)
            guard generation == sessionGeneration else { return }
            playlists = reset ? page.items : playlists + page.items
            playlistOffset = offset + page.receivedCount
            hasMorePlaylists = playlistOffset < page.total && page.receivedCount > 0
            errorMessage = nil
        } catch {
            if generation == sessionGeneration { handleRequestError(error) }
        }
    }

    func tracks(in playlist: SpotifyPlaylist, offset: Int) async throws -> SpotifyPlaylistTrackPage {
        let generation = sessionGeneration
        let token = try await validToken()
        let page = try await Self.fetchPlaylistTracks(id: playlist.id, token: token, offset: offset)
        guard generation == sessionGeneration else { throw SpotifyRequestError.expiredSession }
        return page
    }

    private func validToken() async throws -> String {
        guard let cookie else { throw SpotifyRequestError.expiredSession }
        if accessToken == nil || tokenExpiresAt <= Date().addingTimeInterval(60) {
            let token = try await Self.fetchToken(cookie: cookie)
            guard self.cookie == cookie else { throw SpotifyRequestError.expiredSession }
            accessToken = token.value
            tokenExpiresAt = token.expiresAt
        }
        guard let accessToken else { throw SpotifyRequestError.expiredSession }
        return accessToken
    }

    private func handleRequestError(_ error: Error) {
        if let requestError = error as? SpotifyRequestError,
           case .expiredSession = requestError {
            signOut()
        }
        errorMessage = error.localizedDescription
    }

    private static func request(_ url: URL, cookie: String? = nil) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("en", forHTTPHeaderField: "Accept-Language")
        request.setValue(desktopUserAgent, forHTTPHeaderField: "User-Agent")
        if let cookie { request.setValue("sp_dc=\(cookie)", forHTTPHeaderField: "Cookie") }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw SpotifyRequestError.invalidResponse("no HTTP response")
        }
        guard (200...299).contains(response.statusCode) else {
            if response.statusCode == 401 { throw SpotifyRequestError.expiredSession }
            throw SpotifyRequestError.http(response.statusCode)
        }
        return data
    }

    private static func jsonObject(_ data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SpotifyRequestError.invalidResponse("expected JSON object")
        }
        return object
    }

    private static func fetchToken(cookie: String) async throws -> (value: String, expiresAt: Date) {
        // Follow the Android client's current web-player token protocol.
        let gistURL = URL(string: "https://api.github.com/gists/22ed9c6ba463899e933427f7de1f0eef")!
        let gist = try jsonObject(await request(gistURL))
        guard let files = gist["files"] as? [String: [String: Any]],
              let content = files.values.compactMap({ $0["content"] as? String }).first,
              let nuances = try JSONSerialization.jsonObject(with: Data(content.utf8)) as? [[String: Any]],
              let latest = nuances.max(by: { ($0["v"] as? Int ?? 0) < ($1["v"] as? Int ?? 0) }),
              let secret = latest["s"] as? String,
              let version = latest["v"] as? Int else {
            throw SpotifyRequestError.invalidResponse("TOTP configuration")
        }

        let timeURL = URL(string: "https://open.spotify.com/api/server-time")!
        let time = try jsonObject(await request(timeURL))
        guard let seconds = time["serverTime"] as? Int else {
            throw SpotifyRequestError.invalidResponse("server time")
        }
        let totp = try oneTimePassword(secret: secret, seconds: seconds)
        var parts = URLComponents(string: "https://open.spotify.com/api/token")!
        parts.queryItems = [
            URLQueryItem(name: "reason", value: "transport"),
            URLQueryItem(name: "productType", value: "web-player"),
            URLQueryItem(name: "totp", value: totp),
            URLQueryItem(name: "totpServer", value: totp),
            URLQueryItem(name: "totpVer", value: String(version))
        ]
        let response = try jsonObject(await request(parts.url!, cookie: cookie))
        guard response["isAnonymous"] as? Bool != true,
              let token = response["accessToken"] as? String, !token.isEmpty,
              let expiry = response["accessTokenExpirationTimestampMs"] as? Double else {
            throw SpotifyRequestError.expiredSession
        }
        return (token, Date(timeIntervalSince1970: expiry / 1000))
    }

    private static func oneTimePassword(secret: String, seconds: Int) throws -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        var decoded = [UInt8]()
        var bits = 0
        var buffer = 0
        for character in secret.uppercased() {
            guard let value = alphabet.firstIndex(of: character) else { continue }
            buffer = (buffer << 5) | value
            bits += 5
            if bits >= 8 {
                bits -= 8
                decoded.append(UInt8((buffer >> bits) & 0xff))
                buffer &= (1 << bits) - 1
            }
        }
        guard !decoded.isEmpty else { throw SpotifyRequestError.invalidResponse("TOTP secret") }
        var counter = UInt64(seconds / 30).bigEndian
        let message = withUnsafeBytes(of: &counter) { Data($0) }
        let key = SymmetricKey(data: Data(decoded))
        let digest = Array(HMAC<Insecure.SHA1>.authenticationCode(for: message, using: key))
        let offset = Int(digest[19] & 0x0f)
        let code = (Int(digest[offset] & 0x7f) << 24)
            | (Int(digest[offset + 1]) << 16)
            | (Int(digest[offset + 2]) << 8)
            | Int(digest[offset + 3])
        return String(format: "%06d", code % 1_000_000)
    }

    private static func searchTracks(_ term: String, token: String) async throws -> [SpotifySearchTrack] {
        let variables: [String: Any] = [
            "searchTerm": term, "offset": 0, "limit": 20, "numberOfTopResults": 5,
            "includeAudiobooks": true, "includeArtistHasConcertsField": false,
            "includePreReleases": false, "includeLocalConcertsField": false,
            "includeAuthors": false
        ]
        let object = try await graphQL(
            operation: "searchDesktop", hash: searchHash, variables: variables, token: token
        )
        guard let dataObject = object["data"] as? [String: Any],
              let search = dataObject["searchV2"] as? [String: Any],
              let section = search["tracksV2"] as? [String: Any],
              let items = section["items"] as? [[String: Any]] else {
            throw SpotifyRequestError.invalidResponse("search results")
        }
        return items.compactMap { item in
            guard let wrapper = item["item"] as? [String: Any],
                  let track = wrapper["data"] as? [String: Any],
                  let name = track["name"] as? String else { return nil }
            let uri = (wrapper["_uri"] as? String) ?? (wrapper["uri"] as? String)
                ?? (track["uri"] as? String) ?? ""
            guard uri.hasPrefix("spotify:track:") else { return nil }
            let artistSection = track["artists"] as? [String: Any]
            let artists = artistSection?["items"] as? [[String: Any]] ?? []
            let artist = artists.compactMap { $0["profile"] as? [String: Any] }
                .compactMap { $0["name"] as? String }.joined(separator: ", ")
            let album = (track["albumOfTrack"] as? [String: Any])?["name"] as? String ?? ""
            return SpotifySearchTrack(id: uri, name: name, artist: artist, album: album)
        }
    }

    private static func graphQL(
        operation: String, hash: String, variables: [String: Any], token: String
    ) async throws -> [String: Any] {
        let body: [String: Any] = [
            "operationName": operation, "variables": variables,
            "extensions": ["persistedQuery": ["version": 1, "sha256Hash": hash]]
        ]
        var request = URLRequest(url: URL(string: "https://api-partner.spotify.com/pathfinder/v2/query")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("WebPlayer", forHTTPHeaderField: "app-platform")
        request.setValue(desktopUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://open.spotify.com", forHTTPHeaderField: "Origin")
        request.setValue("https://open.spotify.com/", forHTTPHeaderField: "Referer")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw SpotifyRequestError.invalidResponse("no HTTP response")
        }
        guard (200...299).contains(response.statusCode) else {
            if response.statusCode == 401 { throw SpotifyRequestError.expiredSession }
            throw SpotifyRequestError.http(response.statusCode)
        }
        let object = try jsonObject(data)
        if let errors = object["errors"] as? [[String: Any]],
           let message = errors.first?["message"] as? String {
            throw SpotifyRequestError.invalidResponse(message)
        }
        return object
    }

    private static func fetchPlaylists(
        token: String, offset: Int
    ) async throws -> (items: [SpotifyPlaylist], total: Int, receivedCount: Int) {
        let variables: [String: Any] = [
            "filters": ["Playlists"], "order": NSNull(), "textFilter": "",
            "features": ["LIKED_SONGS", "YOUR_EPISODES_V2", "PRERELEASES", "EVENTS"],
            "limit": 50, "offset": offset, "flatten": true,
            "expandedFolders": [String](), "folderUri": NSNull(),
            "includeFoldersWhenFlattening": false
        ]
        let object = try await graphQL(
            operation: "libraryV3", hash: libraryHash, variables: variables, token: token
        )
        guard let data = object["data"] as? [String: Any],
              let me = data["me"] as? [String: Any],
              let library = me["libraryV3"] as? [String: Any],
              let rawItems = library["items"] as? [[String: Any]] else {
            throw SpotifyRequestError.invalidResponse("library playlists")
        }
        let items = rawItems.compactMap { element -> SpotifyPlaylist? in
            guard let wrapper = element["item"] as? [String: Any],
                  let type = wrapper["__typename"] as? String,
                  type.contains("Playlist"),
                  let uri = wrapper["_uri"] as? String,
                  uri.hasPrefix("spotify:playlist:"),
                  let info = wrapper["data"] as? [String: Any],
                  info["__typename"] as? String == "Playlist" else { return nil }
            let owner = (info["ownerV2"] as? [String: Any])?["data"] as? [String: Any]
            return SpotifyPlaylist(
                id: String(uri.dropFirst("spotify:playlist:".count)),
                name: info["name"] as? String ?? "Untitled playlist",
                owner: owner?["name"] as? String ?? ""
            )
        }
        return (items, library["totalCount"] as? Int ?? rawItems.count, rawItems.count)
    }

    private static func fetchPlaylistTracks(
        id: String, token: String, offset: Int
    ) async throws -> SpotifyPlaylistTrackPage {
        let variables: [String: Any] = [
            "uri": "spotify:playlist:\(id)", "offset": offset, "limit": 50,
            "enableWatchFeedEntrypoint": false
        ]
        let object = try await graphQL(
            operation: "fetchPlaylist", hash: playlistHash, variables: variables, token: token
        )
        guard let data = object["data"] as? [String: Any],
              let playlist = data["playlistV2"] as? [String: Any],
              let content = playlist["content"] as? [String: Any],
              let items = content["items"] as? [[String: Any]] else {
            throw SpotifyRequestError.invalidResponse("playlist tracks")
        }
        let tracks = items.compactMap { element -> SpotifySearchTrack? in
            guard let wrapper = element["itemV2"] as? [String: Any],
                  let track = wrapper["data"] as? [String: Any],
                  let name = track["name"] as? String else { return nil }
            let uri = (wrapper["_uri"] as? String) ?? (wrapper["uri"] as? String)
                ?? (track["uri"] as? String) ?? ""
            guard uri.hasPrefix("spotify:track:") else { return nil }
            let artists = (track["artists"] as? [String: Any])?["items"] as? [[String: Any]] ?? []
            let artist = artists.compactMap { ($0["profile"] as? [String: Any])?["name"] as? String }
                .joined(separator: ", ")
            let album = (track["albumOfTrack"] as? [String: Any])?["name"] as? String ?? ""
            return SpotifySearchTrack(id: uri, name: name, artist: artist, album: album)
        }
        return SpotifyPlaylistTrackPage(
            tracks: tracks, total: content["totalCount"] as? Int ?? offset + items.count,
            receivedCount: items.count
        )
    }

    private static func keychainQuery() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: keychainService,
         kSecAttrAccount as String: "sp_dc"]
    }

    private static func readCookie() -> String? {
        var query = keychainQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func saveCookie(_ value: String) throws {
        deleteCookie()
        var query = keychainQuery()
        query[kSecValueData as String] = Data(value.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SpotifyRequestError.invalidResponse("could not save session in Keychain (\(status))")
        }
    }

    private static func deleteCookie() {
        SecItemDelete(keychainQuery() as CFDictionary)
    }
}
