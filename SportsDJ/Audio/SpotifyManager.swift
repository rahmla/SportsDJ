import Foundation
import Observation
import CryptoKit
#if os(iOS)
import SpotifyiOS
import UIKit
import AuthenticationServices
#endif

// MARK: - SpotifyManager
//
// Spotify playback is supported on iOS/iPadOS only.
// Uses PKCE Authorization Code flow.
//
// Connection sequence:
//  1. authorize() → in-app browser → PKCE token
//  2. Token obtained → open Spotify app → set pendingConnect flag
//  3. When our app returns to foreground (sceneDidBecomeActive) → appRemote.connect()
//     (SPTAppRemote socket is only available while Spotify runs in background)

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
    private var pkceVerifier: String?
    private var pendingConnect = false
#endif

    // MARK: - Lifecycle

    /// Call this from the app's scenePhase .active handler.
    func sceneDidBecomeActive() {
#if os(iOS)
        guard pendingConnect else { return }
        pendingConnect = false
        appRemote?.connect()
#endif
    }

    // MARK: - Authorize / Connect

    func authorize() {
#if os(iOS)
        let config = SPTConfiguration(clientID: SpotifyConstants.clientID,
                                      redirectURL: SpotifyConstants.redirectURI)
        appRemote = SPTAppRemote(configuration: config, logLevel: .debug)
        appRemote?.delegate = self

        let verifier  = Self.generateCodeVerifier()
        let challenge = Self.codeChallenge(for: verifier)
        pkceVerifier  = verifier

        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id",             value: SpotifyConstants.clientID),
            URLQueryItem(name: "redirect_uri",          value: SpotifyConstants.redirectURI.absoluteString),
            URLQueryItem(name: "response_type",         value: "code"),
            URLQueryItem(name: "scope",                 value: "streaming user-read-playback-state user-modify-playback-state"),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge",        value: challenge),
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
            Task { @MainActor in self.debugLastURL = url.absoluteString }

            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
                  let verifier = self.pkceVerifier
            else {
                let errorParam = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "error" })?.value ?? "unknown"
                Task { @MainActor in self.connectionError = "Auth failed: \(errorParam)" }
                return
            }

            Task { [weak self] in
                guard let self else { return }
                do {
                    let token = try await Self.exchangeCodeForToken(code: code, verifier: verifier)
                    await MainActor.run {
                        self.appRemote?.connectionParameters.accessToken = token
                        // SPTAppRemote requires Spotify to be running and listening on its
                        // local socket. Open Spotify now; once it's backgrounded and our
                        // app returns to foreground, sceneDidBecomeActive() calls connect().
                        self.pendingConnect = true
                        UIApplication.shared.open(URL(string: "spotify://")!)
                    }
                } catch {
                    await MainActor.run {
                        self.connectionError = "Token exchange failed: \(error.localizedDescription)"
                    }
                }
            }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        authSession = session
        session.start()
#endif
    }

    func disconnect() {
#if os(iOS)
        appRemote?.disconnect()
        authSession?.cancel()
        authSession = nil
        pendingConnect = false
#endif
        isConnected = false
    }

    // MARK: - Playback

    func playTrack(uri: String, startOffset: Double = 0) {
#if os(iOS)
        guard isConnected else { return }
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
        guard isConnected else { return }
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

    // MARK: - PKCE helpers

    private static func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64URLEncoded()
    }

    private static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncoded()
    }

    private static func exchangeCodeForToken(code: String, verifier: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams: [String: String] = [
            "grant_type":    "authorization_code",
            "code":          code,
            "redirect_uri":  SpotifyConstants.redirectURI.absoluteString,
            "client_id":     SpotifyConstants.clientID,
            "code_verifier": verifier,
        ]
        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(body)"])
        }
        struct TokenResponse: Decodable { let access_token: String }
        return try JSONDecoder().decode(TokenResponse.self, from: data).access_token
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

// MARK: - Data+Base64URL

private extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
