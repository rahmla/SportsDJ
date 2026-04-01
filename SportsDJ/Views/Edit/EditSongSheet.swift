import SwiftUI
import MusicKit

struct EditSongSheet: View {
    let profileID: UUID
    let onSave: (SongItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var edited: SongItem
    @State private var appleMusicInput = ""
    @State private var isFetchingTitle = false
    @State private var fetchTask: Task<Void, Never>?

    init(song: SongItem, profileID: UUID, onSave: @escaping (SongItem) -> Void) {
        self.profileID = profileID
        self.onSave = onSave
        _edited = State(initialValue: song)
        if case .appleMusicTrack(let id, _) = song.audioSource {
            _appleMusicInput = State(initialValue: id)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Edit Song")
                .font(.headline)
                .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Title
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Title").font(.caption).foregroundStyle(.secondary)
                            if isFetchingTitle {
                                ProgressView().controlSize(.mini)
                            }
                        }
                        TextField("Song title", text: $edited.title)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Apple Music
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Apple Music").font(.caption).foregroundStyle(.secondary)
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

                    // Start offset
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
                    .disabled(edited.startOffset < 0)
            }
            .padding()
        }
        .frame(minWidth: 380, minHeight: 280)
    }

    // MARK: - Track lookup

    private func scheduleTrackFetch(input: String) {
        fetchTask?.cancel()
        let id = AudioSource.extractAppleMusicID(from: input)
        guard !id.isEmpty else { return }
        fetchTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            await fetchTrackTitle(id: id)
        }
    }

    @MainActor
    private func fetchTrackTitle(id: String) async {
        isFetchingTitle = true
        defer { isFetchingTitle = false }
        do {
            var request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(rawValue: id))
            request.limit = 1
            let response = try await request.response()
            if let song = response.items.first {
                edited.title = "\(song.title) – \(song.artistName)"
            }
        } catch {
            // Silently ignore — user can type the title manually
        }
    }

    // MARK: - Save

    private func saveAndDismiss() {
        var result = edited
        let id = AudioSource.extractAppleMusicID(from: appleMusicInput)
        result.audioSource = id.isEmpty ? nil : .appleMusicTrack(id: id, trackName: edited.title)
        onSave(result)
        dismiss()
    }
}
