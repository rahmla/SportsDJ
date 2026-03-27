import SwiftUI

struct PerformanceView: View {
    let profile: SportProfile
    @Environment(AudioPlaybackManager.self) private var audio

    private let occasionColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        VStack(spacing: 16) {
            // Occasion buttons — top grid
            LazyVGrid(columns: occasionColumns, spacing: 8) {
                ForEach(profile.occasionButtons) { button in
                    OccasionButtonView(button: button)
                }
            }
            .padding(.horizontal, 8)

            // Stop + Waiting For Game row
            HStack(spacing: 12) {
                StopButtonView()

                if let waitingSource = profile.waitingForGameSource {
                    WaitingForGameButtonView(source: waitingSource)
                }
            }
            .padding(.horizontal)
            .frame(height: 80)

            Divider()

            // Songs — scrollable list
            SongListView(songs: profile.songs)
        }
        .padding(.top, 12)
    }
}
