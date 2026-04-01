import Foundation
import MusicKit
import Observation

// MARK: - MusicKitManager
//
// Handles Apple Music authorization and playback via MusicKit.
// Requires:
//   • Signing & Capabilities → + Capability → MusicKit (adds entitlement automatically)
//   • Info.plist: NSAppleMusicUsageDescription string
//   • Apple Developer account with MusicKit enabled for the App ID

@Observable
final class MusicKitManager {
    var isAuthorized: Bool = false
    var authorizationError: String?

    private let player = ApplicationMusicPlayer.shared
    var onPlaybackFinished: (() -> Void)?
    private var monitorTask: Task<Void, Never>?

    init() {
        Task { await refreshAuthorizationStatus() }
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        let status = await MusicAuthorization.request()
        await MainActor.run { applyStatus(status) }
    }

    private func refreshAuthorizationStatus() async {
        let status = MusicAuthorization.currentStatus
        await MainActor.run { applyStatus(status) }
    }

    @MainActor
    private func applyStatus(_ status: MusicAuthorization.Status) {
        isAuthorized = (status == .authorized)
        authorizationError = switch status {
        case .authorized:    nil
        case .denied:        "Apple Music access denied. Enable it in Settings → Privacy → Media & Apple Music."
        case .restricted:    "Apple Music access is restricted on this device."
        case .notDetermined: nil
        @unknown default:    nil
        }
    }

    // MARK: - Playback

    func playTrack(id: String, startOffset: Double = 0) {
        Task {
            if !isAuthorized { await requestAuthorization() }
            guard isAuthorized else { return }
            do {
                let songID = MusicItemID(rawValue: id)
                var request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: songID)
                request.limit = 1
                let response = try await request.response()
                guard let song = response.items.first else {
                    print("[MusicKit] Track not found: \(id)")
                    return
                }
                player.queue = ApplicationMusicPlayer.Queue([MusicPlayer.Queue.Entry(song)])
                try await player.play()
                if startOffset > 0 {
                    try await Task.sleep(for: .milliseconds(300))
                    player.playbackTime = startOffset
                }
                startMonitoring()
            } catch {
                print("[MusicKit] playTrack error: \(error)")
            }
        }
    }

    private func startMonitoring() {
        monitorTask?.cancel()
        monitorTask = Task { [weak self] in
            // Wait a moment for playback to start
            try? await Task.sleep(for: .seconds(1))
            while !Task.isCancelled {
                let status = ApplicationMusicPlayer.shared.state.playbackStatus
                if status == .stopped || status == .paused {
                    await MainActor.run { self?.onPlaybackFinished?() }
                    return
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    func playPlaylist(id: String) {
        Task {
            if !isAuthorized { await requestAuthorization() }
            guard isAuthorized else { return }
            do {
                let playlistID = MusicItemID(rawValue: id)
                var request = MusicCatalogResourceRequest<Playlist>(matching: \.id, equalTo: playlistID)
                request.limit = 1
                let response = try await request.response()
                guard var playlist = response.items.first else {
                    print("[MusicKit] Playlist not found: \(id)")
                    return
                }
                playlist = try await playlist.with([.tracks])
                if let tracks = playlist.tracks {
                    player.queue = ApplicationMusicPlayer.Queue(tracks.compactMap { MusicPlayer.Queue.Entry($0) })
                    try await player.play()
                }
            } catch {
                print("[MusicKit] playPlaylist error: \(error)")
            }
        }
    }

    func pause() {
        player.pause()
    }

    func stop() {
        monitorTask?.cancel()
        monitorTask = nil
        player.stop()
    }
}
