import SwiftUI

struct HamburgerMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProfileStore.self) private var store

    let onNewEvent: () -> Void
    let onOpenEvent: () -> Void
    let onImport: () -> Void

    @State private var exportURL: URL?

    private var hasActiveEvent: Bool {
        !store.isEventClosed && store.selectedProfile != nil
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: Event actions
                Section {
                    menuButton(icon: "plus", label: "New event") {
                        dismiss(); onNewEvent()
                    }
                    menuButton(icon: "folder", label: "Open event") {
                        dismiss(); onOpenEvent()
                    }
                    menuButton(icon: "xmark", label: "Close event", disabled: !hasActiveEvent) {
                        store.closeEvent()
                        dismiss()
                    }
                }

                // MARK: Import / Export
                Section {
                    if let url = exportURL {
                        ShareLink(item: url, subject: Text(store.selectedProfile?.name ?? "Event")) {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                        .disabled(!hasActiveEvent)
                    } else {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .foregroundStyle(.secondary)
                    }

                    menuButton(icon: "square.and.arrow.down", label: "Import") {
                        dismiss(); onImport()
                    }
                }

                // MARK: Help / About
                Section {
                    NavigationLink {
                        HelpView()
                    } label: {
                        Label("Help", systemImage: "questionmark.circle")
                    }

                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
                }

                // MARK: Apple Music status
                Section {
                    Label("Apple Music", systemImage: "music.note")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
            .navigationTitle("SportsDJ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear {
            if let profile = store.selectedProfile, !store.isEventClosed {
                exportURL = store.exportJSON(profile: profile)
            }
        }
    }

    @ViewBuilder
    private func menuButton(
        icon: String,
        label: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
        }
        .disabled(disabled)
    }
}

struct HelpView: View {
    var body: some View {
        List {
            Section("Getting Started") {
                Text("Open the menu (≡) to create or open an event. Each event has occasion buttons, a song list, and a waiting-for-game track.")
            }
            Section("Occasion Buttons") {
                Text("Tap a button during the game to play its sound clip. Tapping another button or pressing Stop ends playback.")
            }
            Section("Songs") {
                Text("Songs play in order and auto-advance. The play counter tracks how many times each song was used.")
            }
            Section("Waiting for Game") {
                Text("Set an Apple Music playlist that streams while waiting for the game to start. Tap Stop to end it.")
            }
            Section("Apple Music") {
                Text("Paste an Apple Music share link or song ID when editing a button or song. You can share a link from the Apple Music app.")
            }
        }
        .navigationTitle("Help")
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SportsDJ").font(.headline)
                    Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Text("SportsDJ helps sports DJs manage occasion sounds and music playlists during live sporting events.")
            }
        }
        .navigationTitle("About")
    }
}
