import Foundation
import AVFoundation
import Observation

@Observable
final class AudioPlaybackManager: NSObject {
    var isPlaying: Bool = false
    var currentSource: AudioSource?

    let musicKit = MusicKitManager()

    private var audioPlayer: AVAudioPlayer?

    override init() {
        super.init()
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[Audio] AVAudioSession setup failed: \(error)")
        }
    }

    // MARK: - Public API

    func play(source: AudioSource, startOffset: Double = 0) {
        stop()
        currentSource = source

        switch source {
        case .localFile:
            guard let url = source.resolvedLocalURL else { currentSource = nil; return }
            playLocalFile(url: url, startOffset: startOffset)
        case .appleMusicTrack(let id, _):
            musicKit.playTrack(id: id, startOffset: startOffset)
            isPlaying = true
        case .appleMusicPlaylist(let id, _):
            musicKit.playPlaylist(id: id)
            isPlaying = true
        }
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        if case .appleMusicTrack = currentSource { musicKit.stop() }
        else if case .appleMusicPlaylist = currentSource { musicKit.stop() }
        isPlaying = false
        currentSource = nil
    }

    // MARK: - Local file playback

    private func playLocalFile(url: URL, startOffset: Double = 0) {
        guard let player = try? AVAudioPlayer(contentsOf: url) else {
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
        audioPlayer = nil
        isPlaying = false
        currentSource = nil
    }
}
