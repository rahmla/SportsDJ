import Foundation

enum AudioSource: Codable, Hashable, Equatable {
    case localFile(bookmarkData: Data, fileName: String)
    case spotifyTrack(uri: String, trackName: String)
    case spotifyPlaylist(uri: String, playlistName: String)

    var displayName: String {
        switch self {
        case .localFile(_, let name):          return name
        case .spotifyTrack(_, let name):       return "♫ \(name)"
        case .spotifyPlaylist(_, let name):    return "▶ \(name)"
        }
    }

    var isSpotify: Bool {
        switch self {
        case .spotifyTrack, .spotifyPlaylist: return true
        case .localFile:                      return false
        }
    }

    var resolvedLocalURL: URL? {
        guard case .localFile(let bookmarkData, _) = self else { return nil }
        var isStale = false
        return try? URL(resolvingBookmarkData: bookmarkData, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
    }
}
