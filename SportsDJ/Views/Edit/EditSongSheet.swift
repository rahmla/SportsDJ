import SwiftUI
import MusicKit

struct EditSongSheet: View {
    let profileID: UUID
    let isAdding: Bool
    let onSave: (SongItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var edited: SongItem
    @State private var appleMusicInput = ""
    @State private var isFetchPending = false   // debounce window
    @State private var isFetchingTitle = false  // network in flight
    @State private var fetchTask: Task<Void, Never>?

    private var isBusy: Bool { isFetchPending || isFetchingTitle }

    init(song: SongItem, profileID: UUID, isAdding: Bool = false, onSave: @escaping (SongItem) -> Void) {
        self.profileID = profileID
        self.isAdding = isAdding
        self.onSave = onSave
        _edited = State(initialValue: song)
        if case .appleMusicTrack(let id, _) = song.audioSource {
            _appleMusicInput = State(initialValue: id)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(isAdding ? "Add Song" : "Edit Song")
                .font(.headline)
                .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Title — hidden when first adding; shown when editing existing song
                    if !isAdding {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Title").font(.caption).foregroundStyle(.secondary)
                                if isBusy { ProgressView().controlSize(.mini) }
                            }
                            TextField("Song title", text: $edited.title)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    // Apple Music URI
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Apple Music").font(.caption).foregroundStyle(.secondary)
                            if isAdding && isBusy { ProgressView().controlSize(.mini) }
                        }
                        TextField("Song ID or share URL", text: $appleMusicInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption.monospaced())
                            .autocorrectionDisabled()
                            .disableAutocapitalization()
                            .onChange(of: appleMusicInput) { _, newValue in
                                scheduleTrackFetch(input: newValue)
                            }
                        Text("Paste a song ID or share link — title will be filled automatically")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }

                    // Start offset — not shown when adding a new song
                    if !isAdding {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Playback").font(.caption).foregroundStyle(.secondary)
                            HStack {
                                Text("Start at (seconds)")
                                Spacer()
                                TextField("0", value: $edited.startOffset, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                    .foregroundStyle(edited.startOffset < 0 ? Color.red : Color.primary)
                                    .onChange(of: edited.startOffset) { _, new in
                                        if new < 0 { edited.startOffset = 0 }
                                    }
                                    #if os(iOS)
                                    .keyboardType(.decimalPad)
                                    #endif
                            }
                            if edited.startOffset < 0 {
                                Text("Offset must be 0 or greater.")
                                    .font(.caption).foregroundStyle(.red)
                            }
                        }
                    }
                }
                .padding()
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { saveAndDismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(isBusy || edited.startOffset < 0)
            }
            .padding()
        }
        .frame(minWidth: 380, minHeight: 280)
    }

    // MARK: - Track lookup

    private func scheduleTrackFetch(input: String) {
        fetchTask?.cancel()
        let id = AudioSource.extractAppleMusicID(from: input)
        guard !id.isEmpty else { isFetchPending = false; return }
        isFetchPending = true
        fetchTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            await fetchTrackTitle(id: id)
        }
    }

    @MainActor
    private func fetchTrackTitle(id: String) async {
        isFetchPending = false
        isFetchingTitle = true
        defer { isFetchingTitle = false }
        do {
            // Ensure authorized
            if MusicAuthorization.currentStatus != .authorized {
                let status = await MusicAuthorization.request()
                guard status == .authorized else { return }
            }
            var request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(rawValue: id))
            request.limit = 1
            let response = try await request.response()
            if let song = response.items.first {
                edited.title = "\(song.title) – \(song.artistName)"
            }
        } catch {
            print("[EditSongSheet] fetchTrackTitle error: \(error)")
        }
    }

    // MARK: - Save

    private func saveAndDismiss() {
        var result = edited
        // Fallback title if fetch failed or wasn't triggered
        if result.title.isEmpty {
            result.title = "Unknown"
        }
        let id = AudioSource.extractAppleMusicID(from: appleMusicInput)
        result.audioSource = id.isEmpty ? nil : .appleMusicTrack(id: id, trackName: result.title)
        onSave(result)
        dismiss()
    }
}
