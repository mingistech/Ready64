import AppKit
import SwiftUI

/// Cleans up document-window chrome: no title text, no title menu chevron,
/// no titlebar hairline. Traffic lights stay.
struct WindowChromeConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.isHidden = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            Self.applyChrome(to: nsView.window)
        }
        // DocumentGroup sometimes reinserts the title menu after layout.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            Self.applyChrome(to: nsView.window)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            Self.applyChrome(to: nsView.window)
        }
    }

    private static func applyChrome(to window: NSWindow?) {
        guard let window else { return }
        window.titlebarSeparatorStyle = .none
        window.titleVisibility = .hidden
        window.standardWindowButton(.documentIconButton)?.isHidden = true

        let trafficLights: Set<ObjectIdentifier> = [
            window.standardWindowButton(.closeButton),
            window.standardWindowButton(.miniaturizeButton),
            window.standardWindowButton(.zoomButton)
        ]
        .compactMap { $0 }
        .reduce(into: Set<ObjectIdentifier>()) { $0.insert(ObjectIdentifier($1)) }

        if let close = window.standardWindowButton(.closeButton) {
            hideDocumentTitleControls(in: close.superview, protecting: trafficLights)
            hideDocumentTitleControls(in: close.superview?.superview, protecting: trafficLights)
            hideDocumentTitleControls(in: close.superview?.superview?.superview, protecting: trafficLights)
        }
        hideDocumentTitleControls(in: window.contentView, protecting: trafficLights)
    }

    private static func hideDocumentTitleControls(in root: NSView?, protecting trafficLights: Set<ObjectIdentifier>) {
        guard let root else { return }
        var stack: [NSView] = [root]
        while let view = stack.popLast() {
            defer { stack.append(contentsOf: view.subviews) }

            if trafficLights.contains(ObjectIdentifier(view)) {
                continue
            }

            let typeName = String(describing: type(of: view))
            let looksLikeDocumentTitleUI =
                typeName.contains("NSToolbarTitleView")
                || typeName.contains("NSDocument")
                || typeName.contains("DocumentTitle")
                || typeName.contains("TitlebarAccessory")
                || typeName.contains("NSMenuToolbarButton")
                || typeName.contains("NSToolbarSidebar")
                || typeName.contains("_NSThemeDocumentButton")

            if looksLikeDocumentTitleUI {
                view.isHidden = true
                view.alphaValue = 0
                continue
            }

            // Leftover chevron-only control beside the traffic lights.
            if let button = view as? NSButton,
               button.image != nil,
               button.title.isEmpty,
               button.frame.width > 0,
               button.frame.width <= 32,
               button.frame.height <= 32 {
                view.isHidden = true
                view.alphaValue = 0
            }
        }
    }
}
