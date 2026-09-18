import Foundation

private enum SoundCloudResolutionError: LocalizedError {
    case noMatch
    case noStream
    case invalidResponse
    case httpStatus(Int)
    case clientIDUnavailable

    var errorDescription: String? {
        switch self {
        case .noMatch: return "No matching SoundCloud recording was found."
        case .noStream: return "The matching SoundCloud recording has no playable stream."
        case .invalidResponse: return "SoundCloud returned an unexpected response."
        case .httpStatus(let status): return "SoundCloud request failed (HTTP \(status))."
        case .clientIDUnavailable: return "Could not obtain a SoundCloud client ID. Try again later."
        }
    }
}

/// Resolves Spotify metadata to a SoundCloud stream; Spotify supplies no audio.
final class SoundCloudAudioProvider {
    private let api = "https://api-v2.soundcloud.com"
    private let userAgent =
        "Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Mobile Safari/537.36"
    private var clientID: String?

    func resolve(_ track: SpotifySearchTrack) async throws -> URL {
        let id = try await activeClientID()
        do {
            return try await resolve(track, clientID: id)
        } catch SoundCloudResolutionError.httpStatus(let status) where status == 401 || status == 403 {
            clientID = nil
            let refreshedID = try await activeClientID()
            return try await resolve(track, clientID: refreshedID)
        }
    }

    private func resolve(_ track: SpotifySearchTrack, clientID id: String) async throws -> URL {
        var parts = URLComponents(string: api + "/search/tracks")!
        parts.queryItems = [
            URLQueryItem(name: "q", value: "\(track.name) \(track.artist)"),
            URLQueryItem(name: "client_id", value: id),
            URLQueryItem(name: "limit", value: "12")
        ]
        let results = try await json(at: parts.url!)
        guard let collection = results["collection"] as? [[String: Any]] else {
            throw SoundCloudResolutionError.invalidResponse
        }
        let candidates = collection.compactMap { candidate -> (score: Int, data: [String: Any])? in
            guard let title = candidate["title"] as? String,
                  let user = candidate["user"] as? [String: Any] else { return nil }
            let candidateArtist = (user["username"] as? String) ?? (user["full_name"] as? String) ?? ""
            let score = ProviderTrackMatcher.score(
                wantedTitle: track.name, wantedArtist: track.artist,
                candidateTitle: title, candidateArtist: candidateArtist
            )
            return score >= 85 ? (score, candidate) : nil
        }.sorted { $0.score > $1.score }

        guard !candidates.isEmpty else { throw SoundCloudResolutionError.noMatch }
        var streamError: Error?
        for candidate in candidates.prefix(3) {
            guard let media = candidate.data["media"] as? [String: Any],
                  let transcodings = media["transcodings"] as? [[String: Any]] else { continue }
            let preferred = transcodings.first { item in
                (item["format"] as? [String: Any])?["protocol"] as? String == "progressive"
            } ?? transcodings.first { item in
                (item["format"] as? [String: Any])?["protocol"] as? String == "hls"
            }
            guard let endpoint = preferred?["url"] as? String,
                  var streamParts = URLComponents(string: endpoint) else { continue }
            streamParts.queryItems = (streamParts.queryItems ?? []) + [URLQueryItem(name: "client_id", value: id)]
            guard let streamURL = streamParts.url else { continue }
            do {
                let response = try await json(at: streamURL)
                guard let urlString = response["url"] as? String,
                      let url = URL(string: urlString), url.scheme == "https" else { continue }
                return url
            } catch {
                streamError = error
            }
        }
        if let streamError { throw streamError }
        throw SoundCloudResolutionError.noStream
    }

    private func activeClientID() async throws -> String {
        if let clientID { return clientID }
        if let page = try? await fetchData(at: URL(string: "https://soundcloud.com")!, accept: "text/html"),
           let html = String(data: page, encoding: .utf8),
           let pattern = try? NSRegularExpression(pattern: #"https://a-v2\.sndcdn\.com/assets/[^\"]+\.js"#) {
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            for match in pattern.matches(in: html, range: range).reversed() {
                guard let urlRange = Range(match.range, in: html),
                      let scriptURL = URL(string: String(html[urlRange])),
                      let script = try? await fetchData(at: scriptURL, accept: "*/*"),
                      let source = String(data: script, encoding: .utf8),
                      let idRange = source.range(
                        of: #"client_id[:=]\s*\"[A-Za-z0-9]{32}\""#, options: .regularExpression
                      ),
                      let quoted = String(source[idRange]).split(separator: "\"").dropFirst().first else { continue }
                let id = String(quoted)
                clientID = id
                return id
            }
        }
        throw SoundCloudResolutionError.clientIDUnavailable
    }

    private func json(at url: URL) async throws -> [String: Any] {
        let data = try await fetchData(at: url)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SoundCloudResolutionError.invalidResponse
        }
        return object
    }

    private func fetchData(at url: URL, accept: String = "application/json") async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw SoundCloudResolutionError.invalidResponse
        }
        guard (200...299).contains(response.statusCode) else {
            throw SoundCloudResolutionError.httpStatus(response.statusCode)
        }
        return data
    }

}
