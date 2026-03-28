import Foundation
import Observation
#if os(iOS)
import SpotifyiOS
import UIKit
#endif

// MARK: - SpotifyManager
//
// Spotify playback is supported on iOS/iPadOS only.
// On macOS the buttons are visible but Spotify actions are no-ops.

enum SpotifyConstants {
    static let clientID    = "1063298d0bd844eaa7df158a4f86f9d2"
    static let redirectURI = URL(string: "sportsstreamdj://spotify-callback")!
}

@Observable
final class SpotifyManager: NSObject {
    var isConnected: Bool = false
    var connectionError: String?
    var debugLastURL: String = "No callback received yet"

#if os(iOS)
    private var appRemote: SPTAppRemote?
#endif

    // MARK: - Authorize / Connect

    func authorize() {
#if os(iOS)
        let config = SPTConfiguration(clientID: SpotifyConstants.clientID,
                                      redirectURL: SpotifyConstants.redirectURI)
        appRemote = SPTAppRemote(configuration: config, logLevel: .debug)
        appRemote?.delegate = self

        // authorizeAndPlayURI uses the deprecated UIApplication.openURL which iOS blocks.
        // Build the auth URL manually and use the modern open(_:options:completionHandler:).
        let redirect = SpotifyConstants.redirectURI.absoluteString
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "spotify://?token_version=2&client_id=\(SpotifyConstants.clientID)&redirect_uri=\(redirect)&response_type=token&nosignup=true&show_dialog=false&spotifyAppRemoteCallbackURL=\(redirect)"
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url, options: [:]) { [weak self] success in
            if !success {
                Task { @MainActor in
                    self?.connectionError = "Spotify app not found. Please install Spotify."
                }
            }
        }
#endif
    }

    func connect() {
#if os(iOS)
        appRemote?.connect()
#endif
    }

    func disconnect() {
#if os(iOS)
        appRemote?.disconnect()
#endif
        isConnected = false
    }

    // MARK: - Playback

    func playTrack(uri: String, startOffset: Double = 0) {
#if os(iOS)
        guard isConnected else { authorize(); return }
        appRemote?.playerAPI?.play(uri) { [weak self] _, error in
            if let error { print("[Spotify] playTrack error: \(error)") }
            else if startOffset > 0 {
                self?.appRemote?.playerAPI?.seek(toPosition: Int(startOffset * 1000)) { _, _ in }
            }
        }
#else
        print("[Spotify] macOS: playTrack not supported — \(uri)")
#endif
    }

    func playPlaylist(uri: String) {
#if os(iOS)
        guard isConnected else { authorize(); return }
        appRemote?.playerAPI?.play(uri) { _, error in
            if let error { print("[Spotify] playPlaylist error: \(error)") }
        }
#else
        print("[Spotify] macOS: playPlaylist not supported — \(uri)")
#endif
    }

    func pause() {
#if os(iOS)
        guard isConnected else { return }
        appRemote?.playerAPI?.pause { _, _ in }
#endif
    }

    // MARK: - OAuth callback

    func handleCallbackURL(_ url: URL) {
#if os(iOS)
        debugLastURL = url.absoluteString
        guard let params = appRemote?.authorizationParameters(from: url) else {
            connectionError = "Callback received but params missing. appRemote nil: \(appRemote == nil)"
            return
        }
        if let token = params[SPTAppRemoteAccessTokenKey] {
            appRemote?.connectionParameters.accessToken = token
            appRemote?.connect()
        } else if let error = params[SPTAppRemoteErrorDescriptionKey] {
            connectionError = error
        }
#endif
    }
}

// MARK: - SPTAppRemoteDelegate (iOS only)

#if os(iOS)
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
#endif
