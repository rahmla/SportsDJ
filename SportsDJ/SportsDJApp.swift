import SwiftUI

// MARK: - SportsDJ
//
// Xcode setup checklist:
// 1. Targets: set minimum iOS 17
// 2. Signing & Capabilities → + Capability → MusicKit
//    (adds com.apple.developer.music-kit entitlement automatically)
// 3. Signing & Capabilities → + Capability → iCloud → iCloud Documents
//    - Add iCloud container (e.g. iCloud.com.yourname.SportsDJ)
// 4. Info.plist already contains NSAppleMusicUsageDescription
// 5. Apple Developer account must have MusicKit enabled for the App ID

@main
struct SportsDJApp: App {
    @State private var profileStore = ProfileStore()
    @State private var audioManager = AudioPlaybackManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(profileStore)
                .environment(audioManager)
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
