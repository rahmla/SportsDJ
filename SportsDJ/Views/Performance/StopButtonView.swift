import SwiftUI

struct StopButtonView: View {
    @Environment(AudioPlaybackManager.self) private var audio
    @State private var isPressed = false

    private func elapsed(at now: Date) -> TimeInterval {
        guard let start = audio.playbackStartDate else { return 0 }
        return max(0, now.timeIntervalSince(start)) + audio.currentStartOffset
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Button {
                audio.stop()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(audio.isPlaying ? Color.red : Color.red.opacity(0.45))
                        .shadow(color: Color.red.opacity(audio.isPlaying ? 0.5 : 0), radius: 8, y: 3)

                    HStack(spacing: 8) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                        Text("STOP")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        if audio.isPlaying {
                            Text(formatTime(elapsed(at: context.date)))
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.85))
                        }
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
}
