import Foundation
import Observation

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

    // MARK: - Storage directory (iCloud preferred, local fallback)

    private var storageURL: URL {
        if let iCloud = FileManager.default
            .url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents") {
            try? FileManager.default.createDirectory(
                at: iCloud, withIntermediateDirectories: true)
            return iCloud
        }
        return FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
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

    /// Import a profile from an external file URL. Assigns a new ID to avoid conflicts.
    @discardableResult
    func importProfile(from url: URL) -> SportProfile? {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              var profile = try? decoder.decode(SportProfile.self, from: data)
        else { return nil }
        // Give it a fresh ID so it doesn't overwrite an existing profile
        profile.id = UUID()
        save(profile: profile)
        selectedProfile = profile
        return profile
    }

    /// Duplicate the current profile under a new name (Save As).
    @discardableResult
    func saveAs(profile: SportProfile, newName: String) -> SportProfile {
        var copy = profile
        copy.id = UUID()
        copy.name = newName
        save(profile: copy)
        selectedProfile = copy
        return copy
    }
}
