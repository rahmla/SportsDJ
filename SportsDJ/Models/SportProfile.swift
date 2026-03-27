import Foundation

struct SportProfile: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var sport: String
    var occasionButtons: [OccasionButton]
    var songs: [SongItem]
    var waitingForGameSource: AudioSource?

    static let defaultVolleyball = SportProfile(
        name: "Volleyball",
        sport: "Volleyball",
        occasionButtons: [
            OccasionButton(label: "BOOM",  colorHex: "#CC0000"),  // red
            OccasionButton(label: "BLOCK", colorHex: "#0044CC"),  // blue
            OccasionButton(label: "RALLY", colorHex: "#007A00"),  // green
        ],
        songs: [],
        waitingForGameSource: nil
    )
}

struct OccasionButton: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var label: String
    var colorHex: String
    var audioSource: AudioSource?
    var startOffset: Double = 0

    // Custom decoding so startOffset defaults to 0 in older saved profiles
    enum CodingKeys: String, CodingKey {
        case id, label, colorHex, audioSource, startOffset
    }

    init(id: UUID = UUID(), label: String, colorHex: String, audioSource: AudioSource? = nil, startOffset: Double = 0) {
        self.id = id
        self.label = label
        self.colorHex = colorHex
        self.audioSource = audioSource
        self.startOffset = startOffset
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(UUID.self, forKey: .id)
        label       = try c.decode(String.self, forKey: .label)
        colorHex    = try c.decode(String.self, forKey: .colorHex)
        audioSource = try c.decodeIfPresent(AudioSource.self, forKey: .audioSource)
        startOffset = try c.decodeIfPresent(Double.self, forKey: .startOffset) ?? 0
    }
}

struct SongItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var audioSource: AudioSource?
    var order: Int
    var startOffset: Double = 0

    enum CodingKeys: String, CodingKey {
        case id, title, audioSource, order, startOffset
    }

    init(id: UUID = UUID(), title: String, audioSource: AudioSource? = nil, order: Int, startOffset: Double = 0) {
        self.id = id
        self.title = title
        self.audioSource = audioSource
        self.order = order
        self.startOffset = startOffset
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(UUID.self, forKey: .id)
        title       = try c.decode(String.self, forKey: .title)
        audioSource = try c.decodeIfPresent(AudioSource.self, forKey: .audioSource)
        order       = try c.decode(Int.self, forKey: .order)
        startOffset = try c.decodeIfPresent(Double.self, forKey: .startOffset) ?? 0
    }
}
