import Foundation

/// Persisted Ready64 preferences.
enum Ready64Settings {
    static let typefaceKey = "editorTypeface"
    static let insertStartupBannerKey = "insertStartupBanner"

    static var defaultTypeface: Ready64Typeface { .commodore64 }

    /// Reads the startup-banner preference for new-document creation.
    static var insertStartupBanner: Bool {
        UserDefaults.standard.bool(forKey: insertStartupBannerKey)
    }
}
