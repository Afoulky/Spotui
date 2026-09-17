import Foundation

struct ResolvedAudioSource {
    let url: URL
    let provider: String
}

/// The platform player only needs a URL and its source; provider selection stays here.
final class AudioSourceResolver {
    private let qobuz = QobuzAudioProvider()
    private let soundCloud = SoundCloudAudioProvider()

    func resolve(_ track: SpotifySearchTrack) async throws -> ResolvedAudioSource {
        if let url = try? await qobuz.resolve(track) {
            return ResolvedAudioSource(url: url, provider: "Qobuz")
        }
        let url = try await soundCloud.resolve(track)
        return ResolvedAudioSource(url: url, provider: "SoundCloud")
    }
}

enum ProviderTrackMatcher {
    static func score(
        wantedTitle: String, wantedArtist: String, candidateTitle: String, candidateArtist: String
    ) -> Int {
        let title = normalized(wantedTitle)
        let candidate = normalized(candidateTitle)
        let artist = normalized(wantedArtist.components(separatedBy: ",").first ?? wantedArtist)
        let performer = normalized(candidateArtist)
        guard !title.isEmpty, !artist.isEmpty else { return 0 }
        let titleScore: Int
        if candidate == title { titleScore = 110 }
        else if candidate.contains(title) { titleScore = 62 }
        else { return 0 }
        guard performer.contains(artist) || candidate.contains(artist) else { return 0 }
        return titleScore + 38
    }

    private static func normalized(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
}
