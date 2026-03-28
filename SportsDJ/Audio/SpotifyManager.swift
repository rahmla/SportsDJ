import Foundation
import Observation
import CryptoKit
#if os(iOS)
import UIKit
import AuthenticationServices
#endif

// MARK: - SpotifyManager
//
// Auth:     PKCE Authorization Code flow via ASWebAuthenticationSession
// Playback: Spotify Web API (no SPTAppRemote / local socket dependency)
//
// Requires Spotify Premium. Spotify app must be running on the device
// (background is fine) so it appears as an active playback device.

enum SpotifyConstants {
    static let clientID    = "1063298d0bd844eaa7df158a4f86f9d2"
    static let redirectURI = URL(string: "sportsstreamdj://spotify-callback")!
    static let apiBase     = "https://api.spotify.com/v1"
}

private enum SpotifyError: LocalizedError {
    case tokenExpired
    case noActiveDevice
    case api(Int, String)

    var errorDescription: String? {
        switch self {
        case .tokenExpired:    return "Spotify session expired — please reconnect."
        case .noActiveDevice:  return "No active Spotify device. Open Spotify on this device first."
        case .api(let code, let msg): return "Spotify API error \(code): \(msg)"
        }
    }
}

@Observable
final class SpotifyManager: NSObject {
    var isConnected: Bool = false
    var connectionError: String?
    var debugLastURL: String = "No callback received yet"

    private var accessToken: String?

#if os(iOS)
    private var authSession: ASWebAuthenticationSession?
    private var pkceVerifier: String?
#endif

    // MARK: - Authorize

    func authorize() {
#if os(iOS)
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
                // Ignore user-cancelled errors
                let nsError = error as NSError
                if nsError.domain == ASWebAuthenticationSessionError.errorDomain,
                   nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue { return }
                Task { @MainActor in self.connectionError = error.localizedDescription }
                return
            }
            guard let url = callbackURL else { return }
            Task { @MainActor in self.debugLastURL = url.absoluteString }

            guard let comps   = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let code    = comps.queryItems?.first(where: { $0.name == "code" })?.value,
                  let verifier = self.pkceVerifier
            else {
                let err = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "error" })?.value ?? "unknown"
                Task { @MainActor in self.connectionError = "Auth failed: \(err)" }
                return
            }

            Task { [weak self] in
                guard let self else { return }
                do {
                    let token = try await Self.exchangeCodeForToken(code: code, verifier: verifier)
                    await MainActor.run {
                        self.accessToken    = token
                        self.isConnected    = true
                        self.connectionError = nil
                        // Open Spotify so it registers as an active playback device.
                        // User switches back to SportsDJ and playback controls work.
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
        authSession?.cancel()
        authSession = nil
#endif
        accessToken  = nil
        isConnected  = false
    }

    // MARK: - Playback (Web API)

    func playTrack(uri: String, startOffset: Double = 0) {
        guard let token = accessToken else { authorize(); return }
        var body: [String: Any] = ["uris": [uri]]
        if startOffset > 0 { body["position_ms"] = Int(startOffset * 1000) }
        Task { await self.play(token: token, body: body) }
    }

    func playPlaylist(uri: String) {
        guard let token = accessToken else { authorize(); return }
        Task { await self.play(token: token, body: ["context_uri": uri]) }
    }

    func pause() {
        guard let token = accessToken else { return }
        Task { await self.apiCall(token: token, method: "PUT", path: "/me/player/pause") }
    }

    // MARK: - Internal

    /// Play with automatic device activation: if no active device, transfer to the first
    /// available device then retry.
    @MainActor
    private func play(token: String, body: [String: Any]) async {
        do {
            try await Self.webAPIRequest(token: token, method: "PUT", path: "/me/player/play", body: body)
            connectionError = nil
        } catch SpotifyError.noActiveDevice {
            // Find any available device and activate it
            do {
                guard let deviceID = try await Self.firstAvailableDeviceID(token: token) else {
                    connectionError = "No Spotify device found. Open Spotify on this device first."
                    return
                }
                // Transfer playback to that device (play: false = don't auto-start)
                try await Self.webAPIRequest(token: token, method: "PUT", path: "/me/player",
                                             body: ["device_ids": [deviceID], "play": false])
                // Give Spotify a moment to activate the device
                try await Task.sleep(for: .milliseconds(600))
                // Retry play on the now-active device
                try await Self.webAPIRequest(token: token, method: "PUT",
                                             path: "/me/player/play?device_id=\(deviceID)", body: body)
                connectionError = nil
            } catch {
                connectionError = error.localizedDescription
            }
        } catch SpotifyError.tokenExpired {
            accessToken  = nil
            isConnected  = false
            connectionError = SpotifyError.tokenExpired.errorDescription
        } catch {
            connectionError = error.localizedDescription
        }
    }

    @MainActor
    private func apiCall(token: String, method: String, path: String, body: [String: Any]? = nil) async {
        do {
            try await Self.webAPIRequest(token: token, method: method, path: path, body: body)
        } catch SpotifyError.tokenExpired {
            accessToken = nil
            isConnected = false
            connectionError = SpotifyError.tokenExpired.errorDescription
        } catch {
            connectionError = error.localizedDescription
        }
    }

    private static func firstAvailableDeviceID(token: String) async throws -> String? {
        struct Device: Decodable { let id: String?; let is_active: Bool }
        struct DevicesResponse: Decodable { let devices: [Device] }
        var req = URLRequest(url: URL(string: SpotifyConstants.apiBase + "/me/player/devices")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: req)
        let resp = try JSONDecoder().decode(DevicesResponse.self, from: data)
        // Prefer already-active device
        return (resp.devices.first(where: { $0.is_active })?.id ?? resp.devices.first?.id)
    }

    private static func webAPIRequest(
        token: String,
        method: String,
        path: String,
        body: [String: Any]? = nil
    ) async throws {
        var request = URLRequest(url: URL(string: SpotifyConstants.apiBase + path)!)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { return }
        if http.statusCode == 401 { throw SpotifyError.tokenExpired }
        if http.statusCode == 404 { throw SpotifyError.noActiveDevice }
        if http.statusCode >= 400 {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw SpotifyError.api(http.statusCode, msg)
        }
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
            throw URLError(.badServerResponse,
                           userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(body)"])
        }
        struct TokenResponse: Decodable { let access_token: String }
        return try JSONDecoder().decode(TokenResponse.self, from: data).access_token
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding (iOS only)

#if os(iOS)
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
