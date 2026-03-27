import SwiftUI
import UniformTypeIdentifiers

struct EditView: View {
    @Binding var profile: SportProfile
    @Environment(ProfileStore.self) private var store
    @Environment(AudioPlaybackManager.self) private var audio

    @State private var selectedButton: OccasionButton?
    @State private var selectedSong: SongItem?
    @State private var showAddSong = false
    @State private var newSongTitle = ""

    private var sortedSongs: [SongItem] {
        profile.songs.sorted { $0.order < $1.order }
    }

    var body: some View {
        List {
            // Profile metadata
            Section("Profile") {
                HStack {
                    Text("Name").foregroundStyle(.secondary)
                    Spacer()
                    TextField("Profile name", text: $profile.name)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("Sport").foregroundStyle(.secondary)
                    Spacer()
                    TextField("Sport", text: $profile.sport)
                        .multilineTextAlignment(.trailing)
                }
            }

            // Spotify
            Section("Spotify") {
                #if os(iOS)
                HStack {
                    Image(systemName: audio.spotify.isConnected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(audio.spotify.isConnected ? .green : .secondary)
                    Text(audio.spotify.isConnected ? "Connected" : "Not connected")
                        .foregroundStyle(audio.spotify.isConnected ? .primary : .secondary)
                    Spacer()
                    if audio.spotify.isConnected {
                        Button("Disconnect", role: .destructive) {
                            audio.spotify.disconnect()
                        }
                    } else {
                        Button("Connect to Spotify") {
                            audio.spotify.authorize()
                        }
                    }
                }
                if let error = audio.spotify.connectionError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                #else
                Text("Spotify playback is available on iPad/iPhone only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                #endif
            }

            // Waiting for game
            Section("Waiting for Game") {
                WaitingForGameEditRow(source: Binding(
                    get: { profile.waitingForGameSource },
                    set: { profile.waitingForGameSource = $0 }
                ), profileID: profile.id)
            }

            // Occasion buttons
            Section("Occasion Buttons") {
                ForEach(profile.occasionButtons) { button in
                    Button { selectedButton = button } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(hex: button.colorHex) ?? .blue)
                                .frame(width: 28, height: 28)

                            Text(button.label)
                                .foregroundStyle(.primary)
                                .fontWeight(.semibold)

                            Spacer()

                            Text(button.audioSource?.displayName ?? "No audio")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            // Songs
            Section("Songs") {
                ForEach(sortedSongs) { song in
                    Button { selectedSong = song } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "music.note")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)

                            Text(song.title)
                                .foregroundStyle(.primary)

                            Spacer()

                            Text(song.audioSource?.displayName ?? "No audio")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .onMove { from, to in
                    var reordered = sortedSongs
                    reordered.move(fromOffsets: from, toOffset: to)
                    for (i, s) in reordered.enumerated() {
                        if let idx = profile.songs.firstIndex(where: { $0.id == s.id }) {
                            profile.songs[idx].order = i
                        }
                    }
                }
                .onDelete { indexSet in
                    let ids = indexSet.map { sortedSongs[$0].id }
                    profile.songs.removeAll { ids.contains($0.id) }
                }

                Button {
                    showAddSong = true
                } label: {
                    Label("Add Song", systemImage: "plus")
                }
            }
        }
        .navigationTitle("Edit: \(profile.name)")
        .toolbar {
            #if os(iOS)
            EditButton()
            #endif
        }
        .onChange(of: profile) { _, updated in
            store.save(profile: updated)
        }
        .alert("Add Song", isPresented: $showAddSong) {
            TextField("Song title", text: $newSongTitle)
            Button("Add") {
                guard !newSongTitle.isEmpty else { return }
                profile.songs.append(SongItem(title: newSongTitle, order: profile.songs.count))
                newSongTitle = ""
            }
            Button("Cancel", role: .cancel) { newSongTitle = "" }
        }
        .sheet(item: $selectedButton) { button in
            EditOccasionButtonSheet(button: button, profileID: profile.id) { updated in
                if let i = profile.occasionButtons.firstIndex(where: { $0.id == updated.id }) {
                    profile.occasionButtons[i] = updated
                }
            }
        }
        .sheet(item: $selectedSong) { song in
            EditSongSheet(song: song, profileID: profile.id) { updated in
                if let i = profile.songs.firstIndex(where: { $0.id == updated.id }) {
                    profile.songs[i] = updated
                }
            }
        }
    }
}
