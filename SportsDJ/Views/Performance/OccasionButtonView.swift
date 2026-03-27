import SwiftUI

struct OccasionButtonView: View {
    let button: OccasionButton
    @Environment(AudioPlaybackManager.self) private var audio
    @State private var isPressed = false

    private var isPlaying: Bool {
        guard let current = audio.currentSource, let mine = button.audioSource else { return false }
        return current == mine
    }

    private var hasAudio: Bool { button.audioSource != nil }

    var body: some View {
        Button {
            guard let source = button.audioSource else { return }
            audio.play(source: source, startOffset: button.startOffset)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(hex: button.colorHex) ?? .blue)
                    .opacity(hasAudio ? 1.0 : 0.35)
                    .shadow(color: (Color(hex: button.colorHex) ?? .blue).opacity(0.5), radius: isPlaying ? 10 : 4, y: 3)

                VStack(spacing: 6) {
                    Text(button.label)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)

                    if let source = button.audioSource {
                        Text(source.displayName)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                    } else {
                        Text("No audio")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(12)

                if isPlaying {
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(.white, lineWidth: 3)
                }
            }
        }
        .aspectRatio(1.4, contentMode: .fit)
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.93 : 1.0)
        .animation(.spring(response: 0.2), value: isPressed)
        .animation(.easeInOut(duration: 0.2), value: isPlaying)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded   { _ in isPressed = false }
        )
    }
}
