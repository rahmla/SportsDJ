import SwiftUI

struct WaitingForGameEditRow: View {
    @Binding var source: AudioSource?
    let profileID: UUID

    @State private var playlistInput = ""
    @State private var playlistName  = ""
    @State private var hasPlaylist   = false

    init(source: Binding<AudioSource?>, profileID: UUID) {
        _source = source
        self.profileID = profileID
        if case .appleMusicPlaylist(let id, let name) = source.wrappedValue {
            _hasPlaylist   = State(initialValue: true)
            _playlistInput = State(initialValue: id)
            _playlistName  = State(initialValue: name)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Use Apple Music Playlist", isOn: $hasPlaylist)
                .onChange(of: hasPlaylist) { _, enabled in
                    if !enabled { source = nil }
                }

            if hasPlaylist {
                TextField("Playlist name", text: $playlistName)
                    .onChange(of: playlistName) { _, _ in commitSource() }
                TextField("Apple Music Playlist ID or share URL", text: $playlistInput)
                    .font(.caption.monospaced())
                    .autocorrectionDisabled()
                    .disableAutocapitalization()
                    .onChange(of: playlistInput) { _, _ in commitSource() }
            }
        }
    }

    private func commitSource() {
        let id = AudioSource.extractAppleMusicID(from: playlistInput)
        guard !id.isEmpty else { return }
        source = .appleMusicPlaylist(id: id, playlistName: playlistName)
    }
}
