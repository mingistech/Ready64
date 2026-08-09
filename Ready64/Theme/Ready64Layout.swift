import CoreGraphics

/// Layout constants for the C64 presentation layer.
///
/// Document text is never altered by these values — wrapping and column modes
/// are purely a view concern.
enum Ready64Layout {
    /// C64-style border around the editing surface (points).
    /// 0 = no border; increase later to restore the classic frame.
    static let borderWidth: CGFloat = 0

    /// Historic C64 character grid. Reserved for a future authentic mode.
    static let authenticColumns = 40
    static let authenticRows = 25

    /// Viewing modes we expect to support later.
    enum ColumnMode: String, CaseIterable, Identifiable, Sendable {
        case authentic40
        case columns80
        case unrestricted

        var id: String { rawValue }
    }

    /// Milestone 1 uses a responsive, unrestricted editor.
    static var columnMode: ColumnMode = .unrestricted

    /// Default window content size that feels like a C64 screen on modern displays.
    static let defaultContentSize = CGSize(width: 911, height: 683)

    /// Minimum window content size.
    static let minimumContentSize = CGSize(width: 420, height: 320)

    /// Extra space between lines in the editor (points). Presentation-only.
    static let extraLineSpacing: CGFloat = 3
}
