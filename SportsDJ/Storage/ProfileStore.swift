import Foundation
import Observation

@Observable
final class ProfileStore {
    var profiles: [SportProfile] = []
    var selectedProfile: SportProfile?
    var isEventClosed: Bool = false

    private let fileExtension = "sportsdj"
    private let closedKey = "sportsdj.isEventClosed"
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = .prettyPrinted
        return e
    }()
    private let decoder = JSONDecoder()

    init() {
        isEventClosed = UserDefaults.standard.bool(forKey: "sportsdj.isEventClosed")
        loadProfiles()
        if profiles.isEmpty {
            let volleyball = SportProfile.defaultVolleyball
            save(profile: volleyball)
        }
        if selectedProfile == nil {
            selectedProfile = profiles.first
        }
    }

    func closeEvent() {
        isEventClosed = true
        UserDefaults.standard.set(true, forKey: closedKey)
    }

    func openEvent(_ profile: SportProfile) {
        selectedProfile = profile
        isEventClosed = false
        UserDefaults.standard.set(false, forKey: closedKey)
    }

    func exportJSON(profile: SportProfile) -> URL? {
        guard let data = try? encoder.encode(profile) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(profile.name).json")
        try? data.write(to: url)
        return url
    }

    // MARK: - Storage directories

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var storageURL: URL {
        if let iCloud = FileManager.default
            .url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents") {
            try? FileManager.default.createDirectory(at: iCloud, withIntermediateDirectories: true)
            return iCloud
        }
        return documentsURL
    }

    func audioDirectory(for profileID: UUID) -> URL {
        let dir = documentsURL.appendingPathComponent("audio/\(profileID)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Audio file management

    /// Copy a file picked by the user into the profile's audio folder.
    /// Returns the AudioSource with a stable relative path.
    func copyAudioFile(from sourceURL: URL, profileID: UUID) -> AudioSource? {
        let hasAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if hasAccess { sourceURL.stopAccessingSecurityScopedResource() } }

        let destDir = audioDirectory(for: profileID)
        let destURL = destDir.appendingPathComponent(sourceURL.lastPathComponent)

        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            let relativePath = "audio/\(profileID)/\(sourceURL.lastPathComponent)"
            return .localFile(relativePath: relativePath, fileName: sourceURL.lastPathComponent)
        } catch {
            print("[ProfileStore] copyAudioFile error: \(error)")
            return nil
        }
    }

    private func deleteAudioDirectory(for profileID: UUID) {
        let dir = documentsURL.appendingPathComponent("audio/\(profileID)")
        try? FileManager.default.removeItem(at: dir)
    }

    private func copyAudioDirectory(from sourceID: UUID, to destID: UUID) {
        let src = documentsURL.appendingPathComponent("audio/\(sourceID)")
        let dst = documentsURL.appendingPathComponent("audio/\(destID)")
        guard FileManager.default.fileExists(atPath: src.path) else { return }
        try? FileManager.default.copyItem(at: src, to: dst)
    }

    // MARK: - CRUD

    func loadProfiles() {
        let dir = storageURL
        guard let files = try? FileManager.default
            .contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter({ $0.pathExtension == fileExtension })
        else { return }

        profiles = files.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(SportProfile.self, from: data)
        }.sorted { $0.name < $1.name }
    }

    func save(profile: SportProfile) {
        let url = storageURL.appendingPathComponent("\(profile.id).\(fileExtension)")
        guard let data = try? encoder.encode(profile) else { return }
        try? data.write(to: url, options: .atomic)

        if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[idx] = profile
        } else {
            profiles.append(profile)
            profiles.sort { $0.name < $1.name }
        }
        if selectedProfile?.id == profile.id {
            selectedProfile = profile
        }
    }

    func delete(profile: SportProfile) {
        let url = storageURL.appendingPathComponent("\(profile.id).\(fileExtension)")
        try? FileManager.default.removeItem(at: url)
        deleteAudioDirectory(for: profile.id)
        profiles.removeAll { $0.id == profile.id }
        if selectedProfile?.id == profile.id {
            selectedProfile = profiles.first
        }
    }

    func createNew(name: String, sport: String) -> SportProfile {
        var profile = SportProfile.defaultVolleyball
        profile.id = UUID()
        profile.name = name
        profile.sport = sport
        profile.songs = []
        save(profile: profile)
        selectedProfile = profile
        isEventClosed = false
        UserDefaults.standard.set(false, forKey: closedKey)
        return profile
    }

    /// Import a profile from a JSON file. Assigns a new ID.
    @discardableResult
    func importProfile(from url: URL) -> SportProfile? {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              var profile = try? decoder.decode(SportProfile.self, from: data)
        else { return nil }
        profile.id = UUID()
        save(profile: profile)
        selectedProfile = profile
        isEventClosed = false
        UserDefaults.standard.set(false, forKey: closedKey)
        return profile
    }

    /// Duplicate a profile under a new name, copying its audio files.
    @discardableResult
    func saveAs(profile: SportProfile, newName: String) -> SportProfile {
        let newID = UUID()
        var copy = profile
        copy.id = newID
        copy.name = newName
        copy.occasionButtons = copy.occasionButtons.map { remapping($0.audioSource, from: profile.id, to: newID, in: $0) }
        copy.songs            = copy.songs.map            { remapping($0.audioSource, from: profile.id, to: newID, in: $0) }
        copy.waitingForGameSource = remapSource(copy.waitingForGameSource, from: profile.id, to: newID)
        copyAudioDirectory(from: profile.id, to: newID)
        save(profile: copy)
        selectedProfile = copy
        return copy
    }

    private func remapping(_ source: AudioSource?, from old: UUID, to new: UUID, in button: OccasionButton) -> OccasionButton {
        var b = button; b.audioSource = remapSource(source, from: old, to: new); return b
    }
    private func remapping(_ source: AudioSource?, from old: UUID, to new: UUID, in song: SongItem) -> SongItem {
        var s = song; s.audioSource = remapSource(source, from: old, to: new); return s
    }
    private func remapSource(_ source: AudioSource?, from old: UUID, to new: UUID) -> AudioSource? {
        guard case .localFile(let path, let name) = source else { return source }
        return .localFile(relativePath: path.replacingOccurrences(of: "\(old)", with: "\(new)"), fileName: name)
    }

}
