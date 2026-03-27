import SwiftUI
import UniformTypeIdentifiers

/// A FileDocument wrapper for exporting a ZIP file via the system file exporter.
struct ZipExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [] }
    static var writableContentTypes: [UTType] { [.zip] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
