import Foundation

enum AudioSource: Codable, Hashable, Equatable {
    /// A file copied into the app's own Documents/audio/[profileID]/ folder.
    /// relativePath is relative to Documents (e.g. "audio/[uuid]/boom.mp3").
    case localFile(relativePath: String, fileName: String)
    case spotifyTrack(uri: String, trackName: String)
    case spotifyPlaylist(uri: String, playlistName: String)

    var displayName: String {
        switch self {
        case .localFile(_, let name):       return name
        case .spotifyTrack(_, let name):    return "♫ \(name)"
        case .spotifyPlaylist(_, let name): return "▶ \(name)"
        }
    }

    var isSpotify: Bool {
        switch self {
        case .spotifyTrack, .spotifyPlaylist: return true
        case .localFile:                      return false
        }
    }

    /// Resolves the relative path against the app's Documents directory.
    var resolvedLocalURL: URL? {
        guard case .localFile(let relativePath, _) = self else { return nil }
        return FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(relativePath)
    }
}
