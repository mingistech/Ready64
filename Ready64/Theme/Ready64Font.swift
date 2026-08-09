import AppKit
import CoreText

/// Selectable Ready64 typefaces backed by fonts in `Resources/Fonts`.
enum Ready64Typeface: String, CaseIterable, Identifiable, Sendable {
    case commodore64
    case commodoreAngled
    case commodoreRounded

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .commodore64: return "Commodore 64"
        case .commodoreAngled: return "Commodore 64 Angled"
        case .commodoreRounded: return "Commodore 64 Rounded"
        }
    }

    /// PostScript name reported by the font file.
    var postScriptName: String {
        switch self {
        case .commodore64: return "Commodore64"
        case .commodoreAngled: return "Commodore-64-Angled"
        case .commodoreRounded: return "Commodore-64-Rounded"
        }
    }

    /// Filename inside `Resources/Fonts`.
    var resourceFileName: String {
        switch self {
        case .commodore64: return "Commodore-64-v6.3.TTF"
        case .commodoreAngled: return "Commodore Angled v1.2.ttf"
        case .commodoreRounded: return "Commodore Rounded v1.2.ttf"
        }
    }
}

/// Centralized editor typeface selection and bundled-font registration.
enum Ready64Font {
    /// Point size used by the responsive editor.
    static let defaultPointSize: CGFloat = 27

    private static var didRegisterBundledFonts = false

    /// Register fonts shipped in the app bundle so `NSFont(name:)` can resolve them.
    static func registerBundledFonts() {
        if didRegisterBundledFonts,
           NSFont(name: Ready64Typeface.commodore64.postScriptName, size: 12) != nil {
            return
        }

        var registeredAny = false
        for typeface in Ready64Typeface.allCases {
            guard let url = bundledFontURL(for: typeface) else {
                NSLog("Ready64: missing bundled font \(typeface.resourceFileName)")
                continue
            }

            var error: Unmanaged<CFError>?
            if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                registeredAny = true
            } else if let error {
                let description = String(describing: error.takeRetainedValue())
                if description.lowercased().contains("already") {
                    registeredAny = true
                } else {
                    NSLog("Ready64: font registration warning for \(typeface.resourceFileName): \(description)")
                }
            }
        }
        didRegisterBundledFonts = registeredAny
            || NSFont(name: Ready64Typeface.commodore64.postScriptName, size: 12) != nil
    }

    static func editorFont(
        typeface: Ready64Typeface = .commodore64,
        size: CGFloat = defaultPointSize
    ) -> NSFont {
        registerBundledFonts()

        // Resolve by PostScript / family name only. Do not attach empty cascade
        // lists or synthetic character sets — those made Commodore64 text vanish
        // in NSTextView. Font substitution is avoided via Ready64TextStorage.
        if let font = NSFont(name: typeface.postScriptName, size: size) {
            return font
        }
        if let font = NSFont(name: typeface.displayName, size: size) {
            return font
        }

        // Nudge registration once more, then retry name lookup.
        if let url = bundledFontURL(for: typeface) {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            if let font = NSFont(name: typeface.postScriptName, size: size) {
                return font
            }
        }

        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    private static func bundledFontURL(for typeface: Ready64Typeface) -> URL? {
        let fileName = typeface.resourceFileName
        let resourceName = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension

        let subdirectories: [String?] = ["Fonts", "Resources/Fonts", nil]
        for subdirectory in subdirectories {
            if let url = Bundle.main.url(
                forResource: resourceName,
                withExtension: ext,
                subdirectory: subdirectory
            ) {
                return url
            }
        }
        return nil
    }
}
