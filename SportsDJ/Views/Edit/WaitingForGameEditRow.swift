import SwiftUI
import UniformTypeIdentifiers

struct WaitingForGameEditRow: View {
    @Binding var source: AudioSource?
    let profileID: UUID

    @Environment(ProfileStore.self) private var store

    @State private var mode: InputMode = .none
    @State private var playlistURI  = ""
    @State private var playlistName = ""
    @State private var showFilePicker = false

    private enum InputMode: String, CaseIterable {
        case none            = "None"
        case localFile       = "Local MP3"
        case spotifyPlaylist = "Spotify Playlist"
    }

    init(source: Binding<AudioSource?>, profileID: UUID) {
        _source = source
        self.profileID = profileID
        switch source.wrappedValue {
        case .localFile:
            _mode = State(initialValue: .localFile)
        case .spotifyPlaylist(let uri, let name):
            _mode = State(initialValue: .spotifyPlaylist)
            _playlistURI  = State(initialValue: uri)
            _playlistName = State(initialValue: name)
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

            if mode == .spotifyPlaylist {
                TextField("Playlist name", text: $playlistName)
                    .onChange(of: playlistName) { _, _ in commitSource() }
                TextField("Spotify URI  (spotify:playlist:…)", text: $playlistURI)
                    .font(.caption.monospaced())
                    .autocorrectionDisabled()
                    .disableAutocapitalization()
                    .onChange(of: playlistURI) { _, _ in commitSource() }
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
        case .spotifyPlaylist:
            guard !playlistURI.isEmpty else { return }
            source = .spotifyPlaylist(uri: playlistURI, playlistName: playlistName)
        }
    }
}
