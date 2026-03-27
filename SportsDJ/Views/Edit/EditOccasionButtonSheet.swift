import SwiftUI
import UniformTypeIdentifiers

struct EditOccasionButtonSheet: View {
    let profileID: UUID
    let onSave: (OccasionButton) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(ProfileStore.self) private var store
    @State private var edited: OccasionButton
    @State private var selectedColor: Color
    @State private var audioMode: AudioMode = .none
    @State private var spotifyURI  = ""
    @State private var spotifyName = ""
    @State private var showFilePicker = false
    @State private var pendingFileURL: URL?

    private enum AudioMode: String, CaseIterable {
        case none       = "None"
        case localFile  = "Local MP3"
        case spotify    = "Spotify Track"
    }

    init(button: OccasionButton, profileID: UUID, onSave: @escaping (OccasionButton) -> Void) {
        self.profileID = profileID
        self.onSave = onSave
        _edited = State(initialValue: button)
        _selectedColor = State(initialValue: Color(hex: button.colorHex) ?? .blue)
        switch button.audioSource {
        case .localFile:
            _audioMode = State(initialValue: .localFile)
        case .spotifyTrack(let uri, let name):
            _audioMode = State(initialValue: .spotify)
            _spotifyURI  = State(initialValue: uri)
            _spotifyName = State(initialValue: name)
        default:
            _audioMode = State(initialValue: .none)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Edit Button")
                .font(.headline)
                .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Label
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Label").font(.caption).foregroundStyle(.secondary)
                        TextField("Button label", text: $edited.label)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Color
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Color").font(.caption).foregroundStyle(.secondary)
                        ColorPicker("Button color", selection: $selectedColor, supportsOpacity: false)
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

                        if audioMode == .spotify {
                            TextField("Track name", text: $spotifyName)
                                .textFieldStyle(.roundedBorder)
                            TextField("Spotify URI  (spotify:track:…)", text: $spotifyURI)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption.monospaced())
                                .autocorrectionDisabled()
                                .disableAutocapitalization()
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
        .frame(minWidth: 380, minHeight: 380)
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.mp3]) { result in
            pendingFileURL = try? result.get()
            if pendingFileURL != nil { audioMode = .localFile }
        }
    }

    private func saveAndDismiss() {
        var result = edited
        result.colorHex = selectedColor.toHex() ?? edited.colorHex
        switch audioMode {
        case .none:
            result.audioSource = nil
        case .localFile:
            if let url = pendingFileURL {
                result.audioSource = store.copyAudioFile(from: url, profileID: profileID)
            }
            // else keep existing audioSource
        case .spotify:
            result.audioSource = spotifyURI.isEmpty
                ? nil
                : .spotifyTrack(uri: spotifyURI, trackName: spotifyName.isEmpty ? spotifyURI : spotifyName)
        }
        onSave(result)
        dismiss()
    }
}
