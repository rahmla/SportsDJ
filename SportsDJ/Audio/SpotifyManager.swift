import Foundation
import Observation
#if os(iOS)
import SpotifyiOS
import UIKit
import AuthenticationServices
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
    private var authSession: ASWebAuthenticationSession?
#endif

    // MARK: - Authorize / Connect

    func authorize() {
#if os(iOS)
        let config = SPTConfiguration(clientID: SpotifyConstants.clientID,
                                      redirectURL: SpotifyConstants.redirectURI)
        appRemote = SPTAppRemote(configuration: config, logLevel: .debug)
        appRemote?.delegate = self

        // Use standard OAuth web flow — opens in-app browser, no deprecated APIs
        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id",     value: SpotifyConstants.clientID),
            URLQueryItem(name: "redirect_uri",  value: SpotifyConstants.redirectURI.absoluteString),
            URLQueryItem(name: "response_type", value: "token"),
            URLQueryItem(name: "scope",         value: "streaming user-read-playback-state user-modify-playback-state"),
        ]
        guard let authURL = components.url else { return }

        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "sportsstreamdj"
        ) { [weak self] callbackURL, error in
            guard let self else { return }
            if let error {
                Task { @MainActor in self.connectionError = error.localizedDescription }
                return
            }
            guard let url = callbackURL else { return }
            self.debugLastURL = url.absoluteString

            // Implicit grant returns token in URL fragment: #access_token=TOKEN&...
            let fragment = url.fragment ?? url.query ?? ""
            var params: [String: String] = [:]
            for pair in fragment.split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1)
                if kv.count == 2 { params[String(kv[0])] = String(kv[1]) }
            }
            guard let token = params["access_token"] else {
                Task { @MainActor in
                    self.connectionError = "No token in callback: \(url.absoluteString)"
                }
                return
            }
            Task { @MainActor in
                self.appRemote?.connectionParameters.accessToken = token
                self.appRemote?.connect()
            }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        authSession = session
        session.start()
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
        authSession?.cancel()
        authSession = nil
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

    // MARK: - OAuth callback (for onOpenURL fallback)

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
        connectionError = nil
    }
    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        isConnected = false
    }
    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        isConnected = false
        connectionError = error?.localizedDescription
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension SpotifyManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
    }
}
#endif
