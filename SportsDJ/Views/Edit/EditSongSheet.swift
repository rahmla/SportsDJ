import SwiftUI

struct EditSongSheet: View {
    let profileID: UUID
    let onSave: (SongItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var edited: SongItem
    @State private var appleMusicInput = ""
    @State private var isFetchPending = false
    @State private var isFetchingTitle = false
    @State private var fetchTask: Task<Void, Never>?

    private var isBusy: Bool { isFetchPending || isFetchingTitle }

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
            Text(edited.title.isEmpty ? "Add Song" : "Edit Song")
                .font(.headline)
                .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Apple Music URI
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Apple Music").font(.caption).foregroundStyle(.secondary)
                            if isBusy { ProgressView().controlSize(.mini) }
                        }
                        TextField("Song ID or share URL", text: $appleMusicInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption.monospaced())
                            .autocorrectionDisabled()
                            .disableAutocapitalization()
                            .onChange(of: appleMusicInput) { _, newValue in
                                scheduleTrackFetch(input: newValue)
                            }
                        Text("Paste a song ID or share link — title and artist will be filled automatically")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }

                    // Title
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Title").font(.caption).foregroundStyle(.secondary)
                        TextField("Song title", text: $edited.title)
                            .textFieldStyle(.roundedBorder)
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
                    .disabled(isBusy || edited.startOffset < 0 || edited.title.isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 380, minHeight: 280)
    }

    // MARK: - iTunes Lookup (public API, no entitlement needed)

    private func scheduleTrackFetch(input: String) {
        fetchTask?.cancel()
        let id = AudioSource.extractAppleMusicID(from: input)
        guard !id.isEmpty else { isFetchPending = false; return }
        isFetchPending = true
        fetchTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            await fetchTrackInfo(id: id)
        }
    }

    @MainActor
    private func fetchTrackInfo(id: String) async {
        isFetchPending = false
        isFetchingTitle = true
        defer { isFetchingTitle = false }
        guard let url = URL(string: "https://itunes.apple.com/lookup?id=\(id)") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(iTunesLookupResponse.self, from: data)
            if let track = response.results.first {
                edited.title = "\(track.trackName) – \(track.artistName)"
            }
        } catch {
            print("[EditSongSheet] iTunes lookup error: \(error)")
        }
    }

    // MARK: - Save

    private func saveAndDismiss() {
        var result = edited
        let id = AudioSource.extractAppleMusicID(from: appleMusicInput)
        result.audioSource = id.isEmpty ? nil : .appleMusicTrack(id: id, trackName: result.title)
        onSave(result)
        dismiss()
    }
}

// MARK: - iTunes API models

private struct iTunesLookupResponse: Decodable {
    let results: [iTunesTrack]
}

private struct iTunesTrack: Decodable {
    let trackName: String
    let artistName: String
}
