import Foundation

enum AudioSource: Codable, Hashable, Equatable {
    /// A file copied into the app's own Documents/audio/[profileID]/ folder.
    /// relativePath is relative to Documents (e.g. "audio/[uuid]/boom.mp3").
    case localFile(relativePath: String, fileName: String)
    case appleMusicTrack(id: String, trackName: String)
    case appleMusicPlaylist(id: String, playlistName: String)

    var displayName: String {
        switch self {
        case .localFile(_, let name):            return name
        case .appleMusicTrack(_, let name):      return "♫ \(name)"
        case .appleMusicPlaylist(_, let name):   return "▶ \(name)"
        }
    }

    var isAppleMusic: Bool {
        switch self {
        case .appleMusicTrack, .appleMusicPlaylist: return true
        case .localFile:                            return false
        }
    }

    /// Resolves the relative path against the app's Documents directory.
    var resolvedLocalURL: URL? {
        guard case .localFile(let relativePath, _) = self else { return nil }
        return FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(relativePath)
    }

    /// Extracts an Apple Music song ID from a share URL or returns the string as-is.
    static func extractAppleMusicID(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let host = url.host, host.contains("apple.com") else { return trimmed }
        // Album URL with ?i= track parameter
        if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let trackID = comps.queryItems?.first(where: { $0.name == "i" })?.value {
            return trackID
        }
        // Direct song/album URL — last path component is the ID
        return url.lastPathComponent
    }
}
