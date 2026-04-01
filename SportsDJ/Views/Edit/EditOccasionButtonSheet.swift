import SwiftUI

struct EditOccasionButtonSheet: View {
    let profileID: UUID
    let onSave: (OccasionButton) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var edited: OccasionButton
    @State private var selectedColor: Color
    @State private var appleMusicInput = ""

    init(button: OccasionButton, profileID: UUID, onSave: @escaping (OccasionButton) -> Void) {
        self.profileID = profileID
        self.onSave = onSave
        _edited = State(initialValue: button)
        _selectedColor = State(initialValue: Color(hex: button.colorHex) ?? .blue)
        if case .appleMusicTrack(let id, _) = button.audioSource {
            _appleMusicInput = State(initialValue: id)
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

                    // Apple Music
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
        .frame(minWidth: 380, minHeight: 340)
    }

    private func saveAndDismiss() {
        var result = edited
        result.colorHex = selectedColor.toHex() ?? edited.colorHex
        let id = AudioSource.extractAppleMusicID(from: appleMusicInput)
        result.audioSource = id.isEmpty ? nil : .appleMusicTrack(id: id, trackName: edited.label)
        onSave(result)
        dismiss()
    }
}
