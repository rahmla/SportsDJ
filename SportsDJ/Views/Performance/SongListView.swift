import SwiftUI

struct SongListView: View {
    let songs: [SongItem]

    private var sorted: [SongItem] { songs.sorted { $0.order < $1.order } }

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SONGS")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if songs.isEmpty {
                Text("No songs yet — add them in Edit mode")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal)
                    .padding(.top, 4)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(sorted) { song in
                            SongButtonView(song: song)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
        }
    }
}

struct SongButtonView: View {
    let song: SongItem
    @Environment(AudioPlaybackManager.self) private var audio
    @State private var isPressed = false

    private var isPlaying: Bool {
        guard let current = audio.currentSource, let mine = song.audioSource else { return false }
        return current == mine
    }

    var body: some View {
        Button {
            guard let source = song.audioSource else { return }
            audio.play(source: source, startOffset: song.startOffset)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isPlaying ? Color(hex: "#003B8E")! : Color(hex: "#2C2C2E")!)

                HStack(spacing: 6) {
                    Image(systemName: isPlaying ? "speaker.wave.2.fill" : "music.note")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(isPlaying ? 1.0 : 0.7))

                    Text(song.title)
                        .font(.caption)
                        .fontWeight(isPlaying ? .semibold : .regular)
                        .foregroundStyle(song.audioSource == nil ? Color.secondary : Color.white)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)

                if isPlaying {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(0.5), lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.15), value: isPressed)
        .animation(.easeInOut(duration: 0.15), value: isPlaying)
        .opacity(song.audioSource == nil ? 0.45 : 1.0)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded   { _ in isPressed = false }
        )
    }
}
