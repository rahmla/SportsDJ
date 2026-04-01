import SwiftUI
import UniformTypeIdentifiers

struct EditSongSheet: View {
    let profileID: UUID
    let onSave: (SongItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(ProfileStore.self) private var store
    @State private var edited: SongItem
    @State private var audioMode: AudioMode = .none
    @State private var appleMusicInput = ""
    @State private var showFilePicker = false
    @State private var pendingFileURL: URL?

    private enum AudioMode: String, CaseIterable {
        case none       = "None"
        case localFile  = "Local MP3"
        case appleMusic = "Apple Music"
    }

    init(song: SongItem, profileID: UUID, onSave: @escaping (SongItem) -> Void) {
        self.profileID = profileID
        self.onSave = onSave
        _edited = State(initialValue: song)
        switch song.audioSource {
        case .localFile:
            _audioMode = State(initialValue: .localFile)
        case .appleMusicTrack(let id, _):
            _audioMode = State(initialValue: .appleMusic)
            _appleMusicInput = State(initialValue: id)
        default:
            _audioMode = State(initialValue: .none)
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
                        Text("Title").font(.caption).foregroundStyle(.secondary)
                        TextField("Song title", text: $edited.title)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Audio source
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Audio Source").font(.caption).foregroundStyle(.secondary)
                        Picker("Type", selection: $audioMode) {
                            ForEach(AudioMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        if audioMode == .localFile {
                            Button("Select MP3 File") { showFilePicker = true }
                            if let url = pendingFileURL {
                                Text(url.lastPathComponent)
                                    .font(.caption).foregroundStyle(.secondary)
                            } else if case .localFile(_, let name) = edited.audioSource {
                                Text(name).font(.caption).foregroundStyle(.secondary)
                            }
                        }

                        if audioMode == .appleMusic {
                            TextField("Apple Music ID or share URL", text: $appleMusicInput)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption.monospaced())
                                .autocorrectionDisabled()
                                .disableAutocapitalization()
                            Text("Paste a song ID or share link from Apple Music")
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                    }

                    // Start offset
                    if edited.audioSource != nil || pendingFileURL != nil {
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
                    .disabled(edited.startOffset < 0)
            }
            .padding()
        }
        .frame(minWidth: 380, minHeight: 320)
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.mp3]) { result in
            pendingFileURL = try? result.get()
            if pendingFileURL != nil { audioMode = .localFile }
        }
    }

    private func saveAndDismiss() {
        var result = edited
        switch audioMode {
        case .none:
            result.audioSource = nil
        case .localFile:
            if let url = pendingFileURL {
                result.audioSource = store.copyAudioFile(from: url, profileID: profileID)
            }
        case .appleMusic:
            let id = AudioSource.extractAppleMusicID(from: appleMusicInput)
            result.audioSource = id.isEmpty ? nil : .appleMusicTrack(id: id, trackName: edited.title)
        }
        onSave(result)
        dismiss()
    }
}
