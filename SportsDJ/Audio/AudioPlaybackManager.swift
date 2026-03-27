import Foundation
import AVFoundation
import Observation

@Observable
final class AudioPlaybackManager: NSObject {
    var isPlaying: Bool = false
    var currentSource: AudioSource?

    let spotify = SpotifyManager()

    private var audioPlayer: AVAudioPlayer?
    private var securityScopedURL: URL?

    // MARK: - Public API

    func play(source: AudioSource, startOffset: Double = 0) {
        stop()
        currentSource = source

        switch source {
        case .localFile(let bookmarkData, _):
            playLocalFile(bookmarkData: bookmarkData, startOffset: startOffset)
        case .spotifyTrack(let uri, _):
            spotify.playTrack(uri: uri, startOffset: startOffset)
            isPlaying = true
        case .spotifyPlaylist(let uri, _):
            spotify.playPlaylist(uri: uri)
            isPlaying = true
        }
    }

    func stop() {
        // Stop local audio
        audioPlayer?.stop()
        audioPlayer = nil
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil

        // Stop Spotify
        spotify.pause()

        isPlaying = false
        currentSource = nil
    }

    // MARK: - Local file playback

    private func playLocalFile(bookmarkData: Data, startOffset: Double = 0) {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            currentSource = nil
            return
        }

        let hasAccess = url.startAccessingSecurityScopedResource()
        if hasAccess { securityScopedURL = url }

        guard let player = try? AVAudioPlayer(contentsOf: url) else {
            if hasAccess { url.stopAccessingSecurityScopedResource() }
            securityScopedURL = nil
            currentSource = nil
            return
        }

        player.delegate = self
        audioPlayer = player
        if startOffset > 0 { player.currentTime = startOffset }
        player.play()
        isPlaying = true
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlaybackManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil
        audioPlayer = nil
        isPlaying = false
        currentSource = nil
    }
}
