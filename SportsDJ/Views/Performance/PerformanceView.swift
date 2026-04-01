import SwiftUI

struct PerformanceView: View {
    let profile: SportProfile
    @Environment(AudioPlaybackManager.self) private var audio
    @Environment(ProfileStore.self) private var store
    @State private var localProfile: SportProfile

    init(profile: SportProfile) {
        self.profile = profile
        self._localProfile = State(initialValue: profile)
    }

    private let occasionColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    private var sortedSongs: [SongItem] {
        localProfile.songs.sorted { $0.order < $1.order }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Occasion buttons — top grid
            LazyVGrid(columns: occasionColumns, spacing: 8) {
                ForEach(localProfile.occasionButtons) { button in
                    OccasionButtonView(button: button)
                }
            }
            .padding(.horizontal, 8)

            // Stop + Waiting For Game row
            HStack(spacing: 12) {
                StopButtonView()

                if let waitingSource = localProfile.waitingForGameSource {
                    WaitingForGameButtonView(source: waitingSource)
                }
            }
            .padding(.horizontal)
            .frame(height: 80)

            Divider()

            // Songs — scrollable list
            SongListView(songs: localProfile.songs, onPlay: playSong)

            // Reset counters button — only shown when any song has been played
            if localProfile.songs.contains(where: { $0.playCount > 0 }) {
                Button {
                    resetCounters()
                } label: {
                    Text("Reset counters")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }

            Spacer()
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 12)
        .onAppear {
            localProfile = profile
            audio.onTrackFinished = { [self] in
                playNextSong()
            }
        }
        .onChange(of: profile) { _, newProfile in
            localProfile = newProfile
        }
    }

    private func playSong(_ song: SongItem) {
        guard let source = song.audioSource else { return }
        audio.play(source: source, startOffset: song.startOffset)
        incrementPlayCount(for: song)
    }

    private func incrementPlayCount(for song: SongItem) {
        guard let idx = localProfile.songs.firstIndex(where: { $0.id == song.id }) else { return }
        localProfile.songs[idx].playCount += 1
        store.save(profile: localProfile)
    }

    private func playNextSong() {
        guard let last = audio.lastFinishedSource else { return }
        let sorted = sortedSongs
        guard let currentIdx = sorted.firstIndex(where: { $0.audioSource == last }) else { return }
        let nextIdx = currentIdx + 1
        guard nextIdx < sorted.count else { return }
        let nextSong = sorted[nextIdx]
        guard nextSong.audioSource != nil else { return }
        playSong(nextSong)
    }

    private func resetCounters() {
        for idx in localProfile.songs.indices {
            localProfile.songs[idx].playCount = 0
        }
        store.save(profile: localProfile)
    }
}
