import Foundation

/// Classic C64 BASIC startup text that can optionally seed new documents.
enum Ready64StartupBanner {
    /// Exact text inserted at the top of a new document when the setting is on.
    /// This becomes real document content and will be saved with the file.
    static let text = """
          **** COMMODORE 64 BASIC V2 ****

      64K RAM SYSTEM  38911 BASIC BYTES FREE


    READY.

    """

    static func initialDocumentText(insertBanner: Bool) -> String {
        insertBanner ? text : ""
    }
}
