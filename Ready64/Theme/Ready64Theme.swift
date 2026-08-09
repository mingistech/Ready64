import AppKit
import SwiftUI

/// Centralized Commodore-inspired color palette.
///
/// Colors approximate the classic C64 BASIC startup screen (Pepto VIC-II palette).
/// Swap or extend themes here rather than scattering RGB literals through views.
struct Ready64Theme: Equatable, Sendable {
    var name: String

    /// Outer C64-style border surrounding the editing surface.
    var border: NSColor

    /// Main screen / text-view background.
    var screenBackground: NSColor

    /// Primary text / caret-adjacent foreground.
    var foreground: NSColor

    /// Insertion / block cursor fill (matches foreground on classic C64).
    var cursor: NSColor

    /// Selected-text background.
    var selection: NSColor

    // MARK: - SwiftUI conveniences

    var borderColor: Color { Color(nsColor: border) }
    var screenBackgroundColor: Color { Color(nsColor: screenBackground) }
    var foregroundColor: Color { Color(nsColor: foreground) }

    // MARK: - Built-in themes

    /// Classic C64 BASIC screen: blue background, light-blue border & text.
    static let classic = Ready64Theme(
        name: "Classic",
        // Border #453BBF
        border: NSColor(srgbRed: 0x45 / 255, green: 0x3B / 255, blue: 0xBF / 255, alpha: 1),
        // Screen background #2F2896
        screenBackground: NSColor(srgbRed: 0x2F / 255, green: 0x28 / 255, blue: 0x96 / 255, alpha: 1),
        // Text #9387FB
        foreground: NSColor(srgbRed: 0x93 / 255, green: 0x87 / 255, blue: 0xFB / 255, alpha: 1),
        cursor: NSColor(srgbRed: 0x93 / 255, green: 0x87 / 255, blue: 0xFB / 255, alpha: 1),
        // Mid tone between screen and text so selection stays visible
        selection: NSColor(srgbRed: 0x5A / 255, green: 0x4E / 255, blue: 0xC8 / 255, alpha: 1)
    )

    /// Active theme for the app. Change this (or later bind to preferences)
    /// instead of hard-coding colors in editor code.
    static var current: Ready64Theme { .classic }
}
