import SwiftUI

// MARK: - Sports Stream DJ
//
// Xcode setup checklist:
// 1. File > New > Project > Multiplatform > App
// 2. Add all files from this scaffold to the project
// 3. Targets: set minimum iOS 17 / macOS 14
// 4. Signing & Capabilities: enable iCloud > iCloud Documents
//    - Add iCloud container (e.g. iCloud.com.yourname.SportsDJ)
// 5. Info.plist: add NSAppleMusicUsageDescription (for local audio)
// 6. See Audio/SpotifyManager.swift for Spotify SDK setup steps

@main
struct SportsDJApp: App {
    @State private var profileStore = ProfileStore()
    @State private var audioManager = AudioPlaybackManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(profileStore)
                .environment(audioManager)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                audioManager.spotify.sceneDidBecomeActive()
            }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open…") {
                    NotificationCenter.default.post(name: .openProfile, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)

                Divider()

                Button("Save") {
                    NotificationCenter.default.post(name: .saveProfile, object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("Save As…") {
                    NotificationCenter.default.post(name: .saveAsProfile, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Button("Export…") {
                    NotificationCenter.default.post(name: .exportProfile, object: nil)
                }
            }
        }
    }
}

extension Notification.Name {
    static let openProfile   = Notification.Name("openProfile")
    static let saveProfile   = Notification.Name("saveProfile")
    static let saveAsProfile = Notification.Name("saveAsProfile")
    static let exportProfile = Notification.Name("exportProfile")
}
