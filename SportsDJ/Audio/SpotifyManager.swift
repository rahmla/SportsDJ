import Foundation
import Observation
import SpotifyiOS

// MARK: - SpotifyManager
//
// Setup steps (both platforms):
// 1. Register app at https://developer.spotify.com/dashboard
// 2. Add redirect URI "sportsstreamdj://spotify-callback" in Spotify dashboard
// 3. Add URL scheme "sportsstreamdj" to Info.plist (URL Types)
// 4. Add SpotifyiOS SDK via Swift Package Manager:
//    https://github.com/spotify/ios-sdk

enum SpotifyConstants {
    static let clientID    = "1063298d0bd844eaa7df158a4f86f9d2"
    static let redirectURI = URL(string: "sportsstreamdj://spotify-callback")!
}

@Observable
final class SpotifyManager: NSObject {
    var isConnected: Bool = false
    var connectionError: String?

    private var appRemote: SPTAppRemote?

    // MARK: - Authorize / Connect

    func authorize() {
        let config = SPTConfiguration(clientID: SpotifyConstants.clientID,
                                      redirectURL: SpotifyConstants.redirectURI)
        appRemote = SPTAppRemote(configuration: config, logLevel: .debug)
        appRemote?.delegate = self
        appRemote?.authorizeAndPlayURI("")
    }

    func connect() {
        appRemote?.connect()
    }

    func disconnect() {
        appRemote?.disconnect()
        isConnected = false
    }

    // MARK: - Playback

    func playTrack(uri: String, startOffset: Double = 0) {
        guard isConnected else { authorize(); return }
        appRemote?.playerAPI?.play(uri) { [weak self] _, error in
            if let error { print("[Spotify] playTrack error: \(error)") }
            else if startOffset > 0 {
                self?.appRemote?.playerAPI?.seek(toPosition: Int(startOffset * 1000)) { _, _ in }
            }
        }
    }

    func playPlaylist(uri: String) {
        guard isConnected else { authorize(); return }
        appRemote?.playerAPI?.play(uri) { _, error in
            if let error { print("[Spotify] playPlaylist error: \(error)") }
        }
    }

    func pause() {
        guard isConnected else { return }
        appRemote?.playerAPI?.pause { _, _ in }
    }

    // MARK: - OAuth callback

    func handleCallbackURL(_ url: URL) {
        guard let params = appRemote?.authorizationParameters(from: url) else { return }
        if let token = params[SPTAppRemoteAccessTokenKey] {
            appRemote?.connectionParameters.accessToken = token
            appRemote?.connect()
        } else if let error = params[SPTAppRemoteErrorDescriptionKey] {
            connectionError = error
        }
    }
}

// MARK: - SPTAppRemoteDelegate

extension SpotifyManager: SPTAppRemoteDelegate {
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        isConnected = true
    }
    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        isConnected = false
    }
    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        isConnected = false
        connectionError = error?.localizedDescription
    }
}
