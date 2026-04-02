import Foundation
import AVFoundation
import MediaPlayer
import Observation

@Observable
final class AudioPlaybackManager: NSObject {
    var isPlaying: Bool = false
    var currentSource: AudioSource?
    var lastFinishedSource: AudioSource?
    var playbackStartDate: Date?
    var currentStartOffset: Double = 0
    var onTrackFinished: (() -> Void)?

    private let musicPlayer = MPMusicPlayerController.applicationQueuePlayer
    private var audioPlayer: AVAudioPlayer?
    private var manualStop = false

    override init() {
        super.init()
        configureAudioSession()
        musicPlayer.beginGeneratingPlaybackNotifications()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(musicPlaybackStateChanged),
            name: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: musicPlayer
        )
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
        manualStop = false
        currentSource = source
        currentStartOffset = startOffset
        playbackStartDate = Date()

        switch source {
        case .localFile:
            guard let url = source.resolvedLocalURL else { currentSource = nil; return }
            playLocalFile(url: url, startOffset: startOffset)
        case .appleMusicTrack(let id, _):
            playAppleMusicTrack(id: id, startOffset: startOffset)
        case .appleMusicPlaylist(let id, _):
            playAppleMusicTrack(id: id, startOffset: startOffset)
        }
    }

    func stop() {
        manualStop = true
        audioPlayer?.stop()
        audioPlayer = nil
        musicPlayer.stop()
        isPlaying = false
        currentSource = nil
        playbackStartDate = nil
    }

    // MARK: - Apple Music (MediaPlayer)

    private func playAppleMusicTrack(id: String, startOffset: Double) {
        let descriptor = MPMusicPlayerStoreQueueDescriptor(storeIDs: [id])
        musicPlayer.setQueue(with: descriptor)
        musicPlayer.prepareToPlay { [weak self] error in
            guard let self else { return }
            if let error {
                print("[Audio] prepareToPlay error: \(error)")
                DispatchQueue.main.async {
                    self.currentSource = nil
                    self.isPlaying = false
                }
                return
            }
            DispatchQueue.main.async {
                if startOffset > 0 {
                    self.musicPlayer.currentPlaybackTime = startOffset
                }
                self.musicPlayer.play()
                self.isPlaying = true
            }
        }
    }

    @objc private func musicPlaybackStateChanged() {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.manualStop, self.isPlaying else { return }
            guard self.musicPlayer.playbackState == .stopped else { return }
            self.lastFinishedSource = self.currentSource
            self.isPlaying = false
            self.currentSource = nil
            self.playbackStartDate = nil
            self.onTrackFinished?()
        }
    }

    // MARK: - Local file playback

    private func playLocalFile(url: URL, startOffset: Double = 0) {
        guard let player = try? AVAudioPlayer(contentsOf: url) else {
            currentSource = nil; return
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
        playbackStartDate = nil
        guard !manualStop else { currentSource = nil; return }
        lastFinishedSource = currentSource
        currentSource = nil
        onTrackFinished?()
    }
}
