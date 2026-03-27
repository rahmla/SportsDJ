import Foundation
import Observation
import ZIPFoundation

@Observable
final class ProfileStore {
    var profiles: [SportProfile] = []
    var selectedProfile: SportProfile?

    private let fileExtension = "sportsdj"
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = .prettyPrinted
        return e
    }()
    private let decoder = JSONDecoder()

    init() {
        loadProfiles()
        if profiles.isEmpty {
            let volleyball = SportProfile.defaultVolleyball
            save(profile: volleyball)
        }
        if selectedProfile == nil {
            selectedProfile = profiles.first
        }
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

    // MARK: - ZIP Export

    /// Packages the profile JSON + its audio files into a ZIP and returns the temp URL.
    func exportAsZip(profile: SportProfile) throws -> URL {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        // Write profile JSON using portable audio paths (strip the profile UUID segment)
        var portable = profile
        portable.occasionButtons    = portable.occasionButtons.map { portableButton($0, profileID: profile.id) }
        portable.songs              = portable.songs.map            { portableSong($0, profileID: profile.id) }
        portable.waitingForGameSource = portableSource(portable.waitingForGameSource, profileID: profile.id)

        let jsonData = try encoder.encode(portable)
        try jsonData.write(to: tmpDir.appendingPathComponent("profile.json"))

        // Copy audio files (flat, no UUID in path inside the zip)
        let audioSrc = documentsURL.appendingPathComponent("audio/\(profile.id)")
        if FileManager.default.fileExists(atPath: audioSrc.path) {
            try FileManager.default.copyItem(at: audioSrc, to: tmpDir.appendingPathComponent("audio"))
        }

        // Create ZIP
        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(profile.name).sportsdj.zip")
        if FileManager.default.fileExists(atPath: zipURL.path) {
            try FileManager.default.removeItem(at: zipURL)
        }
        try FileManager.default.zipItem(at: tmpDir, to: zipURL, shouldKeepParent: false)
        try? FileManager.default.removeItem(at: tmpDir)
        return zipURL
    }

    private func portableSource(_ source: AudioSource?, profileID: UUID) -> AudioSource? {
        guard case .localFile(let path, let name) = source else { return source }
        return .localFile(relativePath: path.replacingOccurrences(of: "audio/\(profileID)/", with: "audio/"), fileName: name)
    }
    private func portableButton(_ b: OccasionButton, profileID: UUID) -> OccasionButton {
        var x = b; x.audioSource = portableSource(b.audioSource, profileID: profileID); return x
    }
    private func portableSong(_ s: SongItem, profileID: UUID) -> SongItem {
        var x = s; x.audioSource = portableSource(s.audioSource, profileID: profileID); return x
    }

    // MARK: - ZIP Import

    @discardableResult
    func importFromZip(url: URL) throws -> SportProfile? {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }

        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        try FileManager.default.unzipItem(at: url, to: tmpDir)

        guard let data = try? Data(contentsOf: tmpDir.appendingPathComponent("profile.json")),
              var profile = try? decoder.decode(SportProfile.self, from: data)
        else { return nil }

        let newID = UUID()
        profile.id = newID

        // Copy audio files into app storage
        let zipAudioDir = tmpDir.appendingPathComponent("audio")
        if FileManager.default.fileExists(atPath: zipAudioDir.path) {
            let destDir = audioDirectory(for: newID)
            let files = (try? FileManager.default.contentsOfDirectory(at: zipAudioDir, includingPropertiesForKeys: nil)) ?? []
            for file in files {
                try? FileManager.default.copyItem(at: file, to: destDir.appendingPathComponent(file.lastPathComponent))
            }
        }

        // Remap portable paths to absolute relative paths
        profile.occasionButtons    = profile.occasionButtons.map { resolveButton($0, newID: newID) }
        profile.songs              = profile.songs.map            { resolveSong($0, newID: newID) }
        profile.waitingForGameSource = resolveSource(profile.waitingForGameSource, newID: newID)

        save(profile: profile)
        selectedProfile = profile
        return profile
    }

    private func resolveSource(_ source: AudioSource?, newID: UUID) -> AudioSource? {
        guard case .localFile(let path, let name) = source else { return source }
        // "audio/filename" → "audio/[newID]/filename"
        guard path.hasPrefix("audio/"), !path.contains(newID.uuidString) else { return source }
        let filename = String(path.dropFirst("audio/".count))
        return .localFile(relativePath: "audio/\(newID)/\(filename)", fileName: name)
    }
    private func resolveButton(_ b: OccasionButton, newID: UUID) -> OccasionButton {
        var x = b; x.audioSource = resolveSource(b.audioSource, newID: newID); return x
    }
    private func resolveSong(_ s: SongItem, newID: UUID) -> SongItem {
        var x = s; x.audioSource = resolveSource(s.audioSource, newID: newID); return x
    }
}
