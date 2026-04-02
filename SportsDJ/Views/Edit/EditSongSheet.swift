import SwiftUI

struct EditSongSheet: View {
    let profileID: UUID
    let onSave: (SongItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var edited: SongItem
    @State private var appleMusicInput = ""

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
                        Text("Apple Music").font(.caption).foregroundStyle(.secondary)
                        TextField("Song ID or share URL", text: $appleMusicInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption.monospaced())
                            .autocorrectionDisabled()
                            .disableAutocapitalization()
                        Text("Paste a song ID or share link from Apple Music")
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
                    .disabled(edited.startOffset < 0 || edited.title.isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 380, minHeight: 280)
    }

    private func saveAndDismiss() {
        var result = edited
        let id = AudioSource.extractAppleMusicID(from: appleMusicInput)
        result.audioSource = id.isEmpty ? nil : .appleMusicTrack(id: id, trackName: result.title)
        onSave(result)
        dismiss()
    }
}
