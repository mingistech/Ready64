import SwiftUI

/// Document window contents: C64 presentation chrome around the NSTextView editor.
struct EditorView: View {
    @Binding var document: TextDocument

    @AppStorage(Ready64Settings.typefaceKey)
    private var typefaceRaw = Ready64Settings.defaultTypeface.rawValue

    private let theme = Ready64Theme.current

    private var typeface: Ready64Typeface {
        Ready64Typeface(rawValue: typefaceRaw) ?? Ready64Settings.defaultTypeface
    }

    var body: some View {
        // Border color fills the window; the editor is inset so any future
        // C64 frame surrounds the darker screen.
        ZStack {
            theme.borderColor

            Ready64TextView(
                text: $document.text,
                theme: theme,
                font: Ready64Font.editorFont(typeface: typeface)
            )
            .padding(Ready64Layout.borderWidth)
        }
        .ignoresSafeArea()
        .frame(
            minWidth: Ready64Layout.minimumContentSize.width,
            minHeight: Ready64Layout.minimumContentSize.height
        )
    }
}

#Preview {
    EditorView(document: .constant(TextDocument(text: "READY.\n")))
        .frame(width: 760, height: 540)
}
