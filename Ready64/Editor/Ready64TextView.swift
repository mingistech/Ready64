import AppKit
import SwiftUI

/// NSTextView bridge — the real editing engine behind Ready64's C64 skin.
///
/// Uses AppKit's NSTextView for undo/redo, selection, clipboard, find,
/// keyboard navigation, and large-document behavior. SwiftUI TextEditor is
/// intentionally not used as the primary editor.
struct Ready64TextView: NSViewRepresentable {
    @Binding var text: String

    var theme: Ready64Theme = .current
    var font: NSFont = Ready64Font.editorFont()
    var crtParameters: CRTEffectParameters = .default

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> Ready64EditorHostView {
        Ready64Font.registerBundledFonts()

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.autoresizingMask = [.width, .height]

        // Custom storage avoids AppKit substituting Helvetica for Commodore64
        // (that face has empty Unicode coverage metadata).
        let textStorage = Ready64TextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let container = NSTextContainer(size: NSSize(
            width: max(scrollView.contentSize.width, 1),
            height: CGFloat.greatestFiniteMagnitude
        ))
        container.widthTracksTextView = true
        // Soft wrapping is a view concern only; the document keeps real newlines.
        container.lineFragmentPadding = 2
        layoutManager.addTextContainer(container)

        let textView = Ready64NSTextView(frame: .zero, textContainer: container)
        context.coordinator.textView = textView

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.usesFindBar = true
        textView.usesFindPanel = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainerInset = NSSize(width: 4, height: 8)
        textView.autoresizingMask = [.width]

        // Apply chrome/font before assigning text so the initial string picks up
        // the C64 face instead of the system default.
        applyChrome(to: textView, replaceExistingFont: true)
        textView.string = text
        applyFontToEntireDocument(textView)

        context.coordinator.appliedFontName = font.fontName
        context.coordinator.appliedFontSize = font.pointSize

        scrollView.documentView = textView

        let host = Ready64EditorHostView(scrollView: scrollView)
        host.crtParameters = crtParameters

        // Defer first-responder so the view is in a window before focusing.
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }

        return host
    }

    func updateNSView(_ host: Ready64EditorHostView, context: Context) {
        Ready64Font.registerBundledFonts()
        context.coordinator.text = $text
        host.crtParameters = crtParameters

        let scrollView = host.scrollView
        guard let textView = scrollView.documentView as? Ready64NSTextView else { return }

        var textReplaced = false
        // Avoid clobbering in-progress typing / IME composition when the binding
        // already matches what the text view holds.
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
            textReplaced = true
        }

        let fontChanged = context.coordinator.appliedFontName != font.fontName
            || abs((context.coordinator.appliedFontSize ?? 0) - font.pointSize) > 0.05

        applyChrome(to: textView, replaceExistingFont: fontChanged || textReplaced)
        if fontChanged {
            context.coordinator.appliedFontName = font.fontName
            context.coordinator.appliedFontSize = font.pointSize
        }

        if !context.coordinator.didClaimFocus {
            context.coordinator.didClaimFocus = true
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    private func applyChrome(to textView: Ready64NSTextView, replaceExistingFont: Bool = true) {
        textView.drawsBackground = true
        textView.backgroundColor = theme.screenBackground
        textView.textColor = theme.foreground
        textView.insertionPointColor = theme.cursor
        textView.blockCursorColor = theme.cursor
        // Glyph under the block cursor uses the screen color (C64 invert look).
        textView.cursorGlyphColor = theme.screenBackground
        textView.selectedTextAttributes = [
            .backgroundColor: theme.selection,
            .foregroundColor: theme.foreground
        ]

        // Always keep typing attributes current so new keystrokes use the face.
        textView.defaultParagraphStyle = editorParagraphStyle()
        textView.typingAttributes = typingAttributes()
        textView.font = font

        guard replaceExistingFont else { return }
        applyFontToEntireDocument(textView)
    }

    private func editorParagraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = Ready64Layout.extraLineSpacing
        return style
    }

    private func typingAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: font,
            .foregroundColor: theme.foreground,
            .paragraphStyle: editorParagraphStyle()
        ]
    }

    private func applyFontToEntireDocument(_ textView: Ready64NSTextView) {
        // Presentation-only font updates should not create undo events or alter
        // the plain-text document contents.
        let undoManager = textView.undoManager
        undoManager?.disableUndoRegistration()
        defer { undoManager?.enableUndoRegistration() }

        textView.font = font
        textView.defaultParagraphStyle = editorParagraphStyle()
        textView.typingAttributes = typingAttributes()

        guard let storage = textView.textStorage, storage.length > 0 else { return }
        let fullRange = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.addAttributes(typingAttributes(), range: fullRange)
        storage.endEditing()
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        weak var textView: Ready64NSTextView?
        var didClaimFocus = false
        var appliedFontName: String?
        var appliedFontSize: CGFloat?

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            // Push plain string only — never attributed presentation state.
            text.wrappedValue = textView.string
        }
    }
}
