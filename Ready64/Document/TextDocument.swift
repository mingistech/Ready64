import SwiftUI
import UniformTypeIdentifiers

/// Plain-text document model.
///
/// Ready64 stores only UTF-8 text. Theme, font, and cursor presentation are
/// never serialized into the file.
struct TextDocument: FileDocument, Equatable {
    /// Types we can open today. Additional plain-text UTIs (Markdown, etc.)
    /// can be appended here later without changing the storage model.
    static var readableContentTypes: [UTType] {
        [.plainText, .utf8PlainText, .text]
    }

    /// Default save format is UTF-8 plain text (`.txt`).
    static var writableContentTypes: [UTType] {
        [.utf8PlainText]
    }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    /// Factory used by `DocumentGroup` for ⌘N / new untitled documents.
    static func makeNew() -> TextDocument {
        TextDocument(
            text: Ready64StartupBanner.initialDocumentText(
                insertBanner: Ready64Settings.insertStartupBanner
            )
        )
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        // Prefer UTF-8; fall back to lossy conversion so older Mac text files
        // still open rather than failing outright.
        if let string = String(data: data, encoding: .utf8) {
            text = string
        } else if let string = String(data: data, encoding: .macOSRoman) {
            text = string
        } else {
            text = String(decoding: data, as: UTF8.self)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(text.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}
