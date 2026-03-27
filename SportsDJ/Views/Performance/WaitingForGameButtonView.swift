import SwiftUI

struct WaitingForGameButtonView: View {
    let source: AudioSource
    @Environment(AudioPlaybackManager.self) private var audio
    @State private var isPressed = false

    private var isPlaying: Bool { audio.currentSource == source }

    var body: some View {
        Button {
            audio.play(source: source)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(isPlaying ? Color.green : Color.green.opacity(0.7))
                    .shadow(color: Color.green.opacity(isPlaying ? 0.5 : 0), radius: 8, y: 3)

                VStack(spacing: 4) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Text("WAITING FOR GAME")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 8)

                if isPlaying {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.white, lineWidth: 2.5)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.15), value: isPressed)
        .animation(.easeInOut(duration: 0.2), value: isPlaying)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded   { _ in isPressed = false }
        )
    }
}
