import Foundation
import Observation

// MARK: - SpotifyManager
//
// Setup steps (both platforms):
// 1. Register app at https://developer.spotify.com/dashboard
// 2. Replace "YOUR_SPOTIFY_CLIENT_ID" below with your Client ID
// 3. Add redirect URI "sportsstreamdj://spotify-callback" in Spotify dashboard
// 4. Add URL scheme "sportsstreamdj" to Info.plist (URL Types)
// 5. Add SpotifyiOS SDK via Swift Package Manager:
//    https://github.com/spotify/spotify-ios-sdk
// 6. Uncomment all TODO lines below

// TODO: import SpotifyiOS

enum SpotifyConstants {
    static let clientID    = "YOUR_SPOTIFY_CLIENT_ID"
    static let redirectURI = URL(string: "sportsstreamdj://spotify-callback")!
}

@Observable
final class SpotifyManager {
    var isConnected: Bool = false
    var connectionError: String?

    // TODO: private var appRemote: SPTAppRemote?

    // MARK: - Authorize / Connect

    func authorize() {
        // TODO:
        // let config = SPTConfiguration(clientID: SpotifyConstants.clientID,
        //                               redirectURL: SpotifyConstants.redirectURI)
        // appRemote = SPTAppRemote(configuration: config, logLevel: .debug)
        // appRemote?.delegate = self
        // appRemote?.authorizeAndPlayURI("")
        print("[Spotify] authorize() — SDK not yet configured")
    }

    func connect() {
        // TODO: appRemote?.connect()
    }

    func disconnect() {
        // TODO: appRemote?.disconnect()
        isConnected = false
    }

    // MARK: - Playback

    func playTrack(uri: String, startOffset: Double = 0) {
        guard isConnected else { authorize(); return }
        // TODO: appRemote?.playerAPI?.play(uri) { _, error in
        //     if let error { print("[Spotify] playTrack error: \(error)") }
        // }
        // TODO: if startOffset > 0 {
        //     appRemote?.playerAPI?.seek(toPosition: Int(startOffset * 1000)) { _, _ in }
        // }
        print("[Spotify] playTrack: \(uri) offset: \(startOffset)s")
    }

    func playPlaylist(uri: String) {
        guard isConnected else { authorize(); return }
        // TODO: appRemote?.playerAPI?.play(uri) { _, error in
        //     if let error { print("[Spotify] playPlaylist error: \(error)") }
        // }
        print("[Spotify] playPlaylist: \(uri)")
    }

    func pause() {
        guard isConnected else { return }
        // TODO: appRemote?.playerAPI?.pause { _, _ in }
        print("[Spotify] pause()")
    }

    // MARK: - OAuth callback

    func handleCallbackURL(_ url: URL) {
        // TODO:
        // guard let params = appRemote?.authorizationParameters(from: url) else { return }
        // if let token = params[SPTAppRemoteAccessTokenKey] {
        //     appRemote?.connectionParameters.accessToken = token
        //     appRemote?.connect()
        // } else if let error = params[SPTAppRemoteErrorDescriptionKey] {
        //     connectionError = error
        // }
        print("[Spotify] handleCallbackURL: \(url)")
    }
}

// TODO: Uncomment when SpotifyiOS SDK is added
// extension SpotifyManager: SPTAppRemoteDelegate {
//     func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
//         isConnected = true
//     }
//     func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
//         isConnected = false
//     }
//     func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
//         isConnected = false
//         connectionError = error?.localizedDescription
//     }
// }
