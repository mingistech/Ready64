import SwiftUI

/// Removes the DocumentGroup title / filename menu from the window toolbar
/// when the OS supports it (macOS 15+).
struct HideToolbarTitleModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.toolbar(removing: .title)
        } else {
            content
        }
    }
}
