import SwiftUI

struct SongListView: View {
    let songs: [SongItem]
    let onPlay: (SongItem) -> Void

    private var sorted: [SongItem] { songs.sorted { $0.order < $1.order } }

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
                VStack(spacing: 6) {
                    ForEach(sorted) { song in
                        SongRowView(song: song, onPlay: onPlay)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct SongRowView: View {
    let song: SongItem
    let onPlay: (SongItem) -> Void
    @Environment(AudioPlaybackManager.self) private var audio
    @State private var isPressed = false

    private var isPlaying: Bool {
        guard let current = audio.currentSource, let mine = song.audioSource else { return false }
        return current == mine
    }

    var body: some View {
        Button {
            guard song.audioSource != nil else { return }
            onPlay(song)
        } label: {
            HStack(spacing: 10) {
                // Play count
                Text("\(song.playCount)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(song.playCount > 0 ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 24, alignment: .trailing)

                // Title
                Text(song.title)
                    .font(.system(size: 14, weight: isPlaying ? .semibold : .regular))
                    .foregroundStyle(song.audioSource == nil ? Color.secondary : Color.white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Playing indicator
                if isPlaying {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isPlaying ? Color(hex: "#003B8E")! : Color(hex: "#2C2C2E")!)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isPlaying ? Color.white.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .opacity(song.audioSource == nil ? 0.45 : 1.0)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.15), value: isPressed)
        .animation(.easeInOut(duration: 0.15), value: isPlaying)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded   { _ in isPressed = false }
        )
    }
}
