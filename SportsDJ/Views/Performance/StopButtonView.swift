import SwiftUI

struct StopButtonView: View {
    @Environment(AudioPlaybackManager.self) private var audio
    @State private var isPressed = false

    var body: some View {
        Button {
            audio.stop()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(audio.isPlaying ? Color.red : Color.red.opacity(0.45))
                    .shadow(color: Color.red.opacity(audio.isPlaying ? 0.5 : 0), radius: 8, y: 3)

                HStack(spacing: 8) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                    Text("STOP")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.15), value: isPressed)
        .animation(.easeInOut(duration: 0.2), value: audio.isPlaying)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded   { _ in isPressed = false }
        )
    }
}
