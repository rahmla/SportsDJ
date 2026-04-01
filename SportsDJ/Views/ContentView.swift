import SwiftUI
import UniformTypeIdentifiers

enum AppMode {
    case performance, edit
}

struct ContentView: View {
    @Environment(ProfileStore.self) private var store
    @Environment(AudioPlaybackManager.self) private var audio
    @State private var mode: AppMode = .performance
    @State private var showProfilePicker = false
    @State private var showOpenFile = false
    @State private var showSaveAs = false
    @State private var saveAsName = ""
    @State private var savedFeedback = false

    var body: some View {
        NavigationStack {
            Group {
                if let profile = store.selectedProfile {
                    switch mode {
                    case .performance:
                        PerformanceView(profile: profile)
                    case .edit:
                        EditView(profile: Binding(
                            get: { profile },
                            set: { store.save(profile: $0) }
                        ))
                    }
                } else {
                    ContentUnavailableView(
                        "No Profile",
                        systemImage: "music.note.list",
                        description: Text("Tap the profile button to create one.")
                    )
                }
            }
            .navigationTitle(store.selectedProfile?.name ?? "Sports Stream DJ")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showProfilePicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "music.note.list")
                            Text(store.selectedProfile?.sport ?? "Profiles")
                                .fontWeight(.semibold)
                        }
                    }
                }

                ToolbarItem(placement: .automatic) {
                    Menu {
                        Button("Open…") { showOpenFile = true }
                        Divider()
                        Button("Save") { explicitSave() }
                            .disabled(store.selectedProfile == nil)
                        Button("Save As…") {
                            saveAsName = store.selectedProfile?.name ?? ""
                            showSaveAs = true
                        }
                        .disabled(store.selectedProfile == nil)
                    } label: {
                        Label(savedFeedback ? "Saved!" : "File", systemImage: savedFeedback ? "checkmark" : "doc")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    if mode == .edit {
                        Button("Done") {
                            audio.stop()
                            mode = .performance
                        }
                        .fontWeight(.semibold)
                    } else {
                        Button {
                            audio.stop()
                            mode = .edit
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showProfilePicker) {
            ProfilePickerView()
        }
        // Wire macOS menu commands
        .onReceive(NotificationCenter.default.publisher(for: .openProfile))   { _ in showOpenFile = true }
        .onReceive(NotificationCenter.default.publisher(for: .saveProfile))   { _ in explicitSave() }
        .onReceive(NotificationCenter.default.publisher(for: .saveAsProfile)) { _ in
            saveAsName = store.selectedProfile?.name ?? ""
            showSaveAs = true
        }
        // Open legacy .json profiles
        .fileImporter(isPresented: $showOpenFile, allowedContentTypes: [.json]) { result in
            guard let url = try? result.get() else { return }
            store.importProfile(from: url)
        }
        // Save As
        .alert("Save As", isPresented: $showSaveAs) {
            TextField("Profile name", text: $saveAsName)
            Button("Save") {
                guard !saveAsName.isEmpty, let profile = store.selectedProfile else { return }
                store.saveAs(profile: profile, newName: saveAsName)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a name for the new profile.")
        }
    }

    private func explicitSave() {
        guard let profile = store.selectedProfile else { return }
        store.save(profile: profile)
        savedFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            savedFeedback = false
        }
    }

}
