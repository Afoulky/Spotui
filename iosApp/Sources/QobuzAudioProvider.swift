import Foundation

private enum QobuzResolutionError: LocalizedError {
    case noMatch
    case noStream

    var errorDescription: String? {
        switch self {
        case .noMatch: return "No matching Qobuz recording was found."
        case .noStream: return "Qobuz did not provide a playable MP3 stream."
        }
    }
}

/// Uses the same community Qobuz resolver endpoints and MP3 quality as Android.
final class QobuzAudioProvider {
    private let endpoints = ["https://qobuz.kennyy.com.br", "https://qobuz2.kennyy.com.br"]

    func resolve(_ track: SpotifySearchTrack) async throws -> URL {
        var foundMatch = false
        for endpoint in endpoints {
            guard var search = URLComponents(string: endpoint + "/search") else { continue }
            search.queryItems = [
                URLQueryItem(name: "q", value: "\(track.name) \(track.artist)"),
                URLQueryItem(name: "limit", value: "8"),
                URLQueryItem(name: "offset", value: "0")
            ]
            guard let searchURL = search.url,
                  let response = try? await json(at: searchURL) else { continue }
            let tracks = response["tracks"] as? [String: Any]
            let items = (tracks?["items"] as? [[String: Any]])
                ?? (response["items"] as? [[String: Any]])
                ?? (response["tracks"] as? [[String: Any]])
                ?? []
            let matches = items.compactMap { item -> (score: Int, id: String)? in
                let title = (item["title"] as? String) ?? (item["name"] as? String) ?? ""
                let artist = ((item["performer"] as? [String: Any])?["name"] as? String)
                    ?? ((item["artist"] as? [String: Any])?["name"] as? String)
                    ?? (item["artist"] as? String) ?? ""
                let score = ProviderTrackMatcher.score(
                    wantedTitle: track.name, wantedArtist: track.artist,
                    candidateTitle: title, candidateArtist: artist
                )
                let id = (item["id"] as? String) ?? (item["id"] as? NSNumber)?.stringValue
                guard score >= 85, let id, !id.isEmpty else { return nil }
                return (score, id)
            }.sorted { $0.score > $1.score }
            if !matches.isEmpty { foundMatch = true }
            for match in matches.prefix(3) {
                guard var stream = URLComponents(string: endpoint + "/track") else { continue }
                stream.queryItems = [
                    URLQueryItem(name: "id", value: match.id),
                    URLQueryItem(name: "quality", value: "5")
                ]
                guard let streamURL = stream.url,
                      let result = try? await json(at: streamURL) else { continue }
                let data = result["data"] as? [String: Any]
                let urlString = (result["url"] as? String) ?? (data?["url"] as? String)
                if let urlString, let url = URL(string: urlString), url.scheme == "https" {
                    return url
                }
            }
        }
        throw foundMatch ? QobuzResolutionError.noStream : QobuzResolutionError.noMatch
    }

    private func json(at url: URL) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("MeloBridge-iOS", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse,
              (200...299).contains(response.statusCode),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw QobuzResolutionError.noStream
        }
        return object
    }
}
