import SwiftUI
import UniformTypeIdentifiers

struct WaitingForGameEditRow: View {
    @Binding var source: AudioSource?
    let profileID: UUID

    @Environment(ProfileStore.self) private var store

    @State private var mode: InputMode = .none
    @State private var playlistInput = ""
    @State private var playlistName  = ""
    @State private var showFilePicker = false

    private enum InputMode: String, CaseIterable {
        case none                = "None"
        case localFile           = "Local MP3"
        case appleMusicPlaylist  = "Apple Music Playlist"
    }

    init(source: Binding<AudioSource?>, profileID: UUID) {
        _source = source
        self.profileID = profileID
        switch source.wrappedValue {
        case .localFile:
            _mode = State(initialValue: .localFile)
        case .appleMusicPlaylist(let id, let name):
            _mode = State(initialValue: .appleMusicPlaylist)
            _playlistInput = State(initialValue: id)
            _playlistName  = State(initialValue: name)
        default:
            _mode = State(initialValue: .none)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Source", selection: $mode) {
                ForEach(InputMode.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
            .onChange(of: mode) { _, _ in commitSource() }

            if mode == .localFile {
                Button("Select MP3 File") { showFilePicker = true }
                if case .localFile(_, let name) = source {
                    Text(name).font(.caption).foregroundStyle(.secondary)
                }
            }

            if mode == .appleMusicPlaylist {
                TextField("Playlist name", text: $playlistName)
                    .onChange(of: playlistName) { _, _ in commitSource() }
                TextField("Apple Music Playlist ID or share URL", text: $playlistInput)
                    .font(.caption.monospaced())
                    .autocorrectionDisabled()
                    .disableAutocapitalization()
                    .onChange(of: playlistInput) { _, _ in commitSource() }
            }
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.mp3]) { result in
            guard let url = try? result.get() else { return }
            source = store.copyAudioFile(from: url, profileID: profileID)
        }
    }

    private func commitSource() {
        switch mode {
        case .none:
            source = nil
        case .localFile:
            break
        case .appleMusicPlaylist:
            let id = AudioSource.extractAppleMusicID(from: playlistInput)
            guard !id.isEmpty else { return }
            source = .appleMusicPlaylist(id: id, playlistName: playlistName)
        }
    }
}
