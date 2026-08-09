import SwiftUI

@main
struct Ready64App: App {
    init() {
        Ready64Font.registerBundledFonts()
    }

    var body: some Scene {
        // Autoclosure: makeNew() runs for each new untitled document.
        DocumentGroup(newDocument: TextDocument.makeNew()) { file in
            EditorView(document: file.$document)
        }
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(
            width: Ready64Layout.defaultContentSize.width,
            height: Ready64Layout.defaultContentSize.height
        )

        Settings {
            SettingsView()
        }
    }
}
