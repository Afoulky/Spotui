import Foundation

private enum SoundCloudResolutionError: LocalizedError {
    case noMatch
    case noStream
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noMatch: return "No matching SoundCloud recording was found."
        case .noStream: return "The matching SoundCloud recording has no playable stream."
        case .invalidResponse: return "SoundCloud returned an unexpected response."
        }
    }
}

/// Resolves Spotify metadata to a SoundCloud stream; Spotify supplies no audio.
final class SoundCloudAudioProvider {
    private let api = "https://api-v2.soundcloud.com"
    private let fallbackClientID = "iZ8g4fkmVfrgwsRotA4tP8hAYzBZu0pE"
    private let userAgent =
        "Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Mobile Safari/537.36"
    private var clientID: String?

    func resolve(_ track: SpotifySearchTrack) async throws -> URL {
        let id = await activeClientID()
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
            let score = matchScore(
                wantedTitle: track.name, wantedArtist: track.artist,
                candidateTitle: title, candidateArtist: candidateArtist
            )
            return score >= 85 ? (score, candidate) : nil
        }.sorted { $0.score > $1.score }

        guard !candidates.isEmpty else { throw SoundCloudResolutionError.noMatch }
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
            guard let streamURL = streamParts.url,
                  let response = try? await json(at: streamURL),
                  let urlString = response["url"] as? String,
                  let url = URL(string: urlString), url.scheme == "https" else { continue }
            return url
        }
        throw SoundCloudResolutionError.noStream
    }

    private func activeClientID() async -> String {
        if let clientID { return clientID }
        if let page = try? await fetchData(at: URL(string: "https://soundcloud.com")!),
           let html = String(data: page, encoding: .utf8),
           let pattern = try? NSRegularExpression(pattern: #"https://a-v2\.sndcdn\.com/assets/[^\"]+\.js"#) {
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            for match in pattern.matches(in: html, range: range).suffix(5).reversed() {
                guard let urlRange = Range(match.range, in: html),
                      let scriptURL = URL(string: String(html[urlRange])),
                      let script = try? await fetchData(at: scriptURL),
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
        clientID = fallbackClientID
        return fallbackClientID
    }

    private func json(at url: URL) async throws -> [String: Any] {
        let data = try await fetchData(at: url)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SoundCloudResolutionError.invalidResponse
        }
        return object
    }

    private func fetchData(at url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
            throw SoundCloudResolutionError.invalidResponse
        }
        return data
    }

    private func matchScore(
        wantedTitle: String, wantedArtist: String, candidateTitle: String, candidateArtist: String
    ) -> Int {
        let title = normalized(wantedTitle)
        let candidate = normalized(candidateTitle)
        let artist = normalized(wantedArtist.components(separatedBy: ",").first ?? wantedArtist)
        let uploader = normalized(candidateArtist)
        guard !title.isEmpty, !artist.isEmpty else { return 0 }
        let titleScore: Int
        if candidate == title { titleScore = 110 }
        else if candidate.contains(title) { titleScore = 62 }
        else { return 0 }
        guard uploader.contains(artist) || candidate.contains(artist) else { return 0 }
        return titleScore + 38
    }

    private func normalized(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
}
