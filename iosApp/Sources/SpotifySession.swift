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
    @Published var errorMessage: String?

    private static let keychainService = "com.music.spotui.ios.spotify"
    private static let searchHash = "4801118d4a100f756e833d33984436a3899cff359c532f8fd3aaf174b60b3b49"
    private static let desktopUserAgent =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
    private var cookie: String?
    private var accessToken: String?
    private var tokenExpiresAt = Date.distantPast

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
        isBusy = true
        defer { isBusy = false }
        do {
            let token = try await Self.fetchToken(cookie: candidate)
            try Self.saveCookie(candidate)
            cookie = candidate
            accessToken = token.value
            tokenExpiresAt = token.expiresAt
            isSignedIn = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
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
        isSignedIn = false
        errorMessage = nil
    }

    func search(_ query: String) async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            results = []
            return
        }
        guard let cookie else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            if accessToken == nil || tokenExpiresAt <= Date().addingTimeInterval(60) {
                let token = try await Self.fetchToken(cookie: cookie)
                accessToken = token.value
                tokenExpiresAt = token.expiresAt
            }
            guard let accessToken else { return }
            results = try await Self.searchTracks(term, token: accessToken)
            errorMessage = nil
        } catch {
            if let requestError = error as? SpotifyRequestError,
               case .expiredSession = requestError {
                signOut()
            }
            errorMessage = error.localizedDescription
        }
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
        let body: [String: Any] = [
            "operationName": "searchDesktop", "variables": variables,
            "extensions": ["persistedQuery": ["version": 1, "sha256Hash": searchHash]]
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
