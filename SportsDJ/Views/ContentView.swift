import SwiftUI
import UniformTypeIdentifiers

enum AppMode {
    case performance, edit
}

struct ContentView: View {
    @Environment(ProfileStore.self) private var store
    @Environment(AudioPlaybackManager.self) private var audio
    @State private var mode: AppMode = .performance
    @State private var showHamburger = false
    @State private var showNewEvent = false
    @State private var showOpenEvent = false
    @State private var showImport = false
    @State private var newEventName = ""
    @State private var newEventSport = ""

    private var activeProfile: SportProfile? {
        store.isEventClosed ? nil : store.selectedProfile
    }

    var body: some View {
        NavigationStack {
            Group {
                if let profile = activeProfile {
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
                    emptyState
                }
            }
            .navigationTitle(activeProfile?.name ?? "SportsDJ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showHamburger = true } label: {
                        Image(systemName: "line.3.horizontal")
                            .imageScale(.large)
                    }
                }
                if activeProfile != nil {
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
        }
        .sheet(isPresented: $showHamburger) {
            HamburgerMenuView(
                onNewEvent: { showNewEvent = true },
                onOpenEvent: { showOpenEvent = true },
                onImport:   { showImport = true }
            )
        }
        .sheet(isPresented: $showOpenEvent) {
            OpenEventView()
        }
        .fileImporter(isPresented: $showImport, allowedContentTypes: [.json]) { result in
            guard let url = try? result.get() else { return }
            store.importProfile(from: url)
        }
        .alert("New Event", isPresented: $showNewEvent) {
            TextField("Event name", text: $newEventName)
            TextField("Sport", text: $newEventSport)
            Button("Create") {
                guard !newEventName.isEmpty else { return }
                _ = store.createNew(
                    name: newEventName,
                    sport: newEventSport.isEmpty ? newEventName : newEventSport
                )
                newEventName = ""; newEventSport = ""
            }
            Button("Cancel", role: .cancel) { newEventName = ""; newEventSport = "" }
        }
        .onChange(of: store.selectedProfile?.id) { _, _ in mode = .performance }
        .onChange(of: store.isEventClosed)       { _, _ in mode = .performance }
        // Wire macOS menu commands
        .onReceive(NotificationCenter.default.publisher(for: .openProfile))   { _ in showOpenEvent = true }
        .onReceive(NotificationCenter.default.publisher(for: .saveProfile))   { _ in
            if let p = activeProfile { store.save(profile: p) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .saveAsProfile)) { _ in showNewEvent = true }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "music.note.list")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("No event open")
                .font(.title2).fontWeight(.semibold)
            Text("Open an existing event or create a new one.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            HStack(spacing: 16) {
                Button("New event") { showNewEvent = true }
                    .buttonStyle(.borderedProminent)
                Button("Open event") { showOpenEvent = true }
                    .buttonStyle(.bordered)
            }
            Spacer()
        }
    }
}
