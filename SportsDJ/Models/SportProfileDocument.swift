import SwiftUI
import UniformTypeIdentifiers

/// Wraps SportProfile as a SwiftUI FileDocument for import/export via file pickers.
struct SportProfileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    var profile: SportProfile

    init(profile: SportProfile) {
        self.profile = profile
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        profile = try JSONDecoder().decode(SportProfile.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(profile)
        return FileWrapper(regularFileWithContents: data)
    }
}
