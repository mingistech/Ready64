import AppKit

/// NSTextView with a classic Commodore 64 blinking block cursor.
///
/// Strategy (macOS 14+):
/// 1. Opt out of `NSTextInsertionIndicator` when possible.
/// 2. Hide any indicator views AppKit still creates.
/// 3. Track the system caret rect for correct vertical alignment, then draw a
///    full character-cell block ourselves.
final class Ready64NSTextView: NSTextView {
    var blockCursorColor: NSColor = .white
    var cursorGlyphColor: NSColor = .black

    private var blinkTimer: Timer?
    private var blinkOn = true
    private var lastDrawnBlock = NSRect.zero

    /// Latest caret rect supplied by AppKit (view coordinates). Used so the
    /// block stays vertically aligned with the glyphs instead of drifting
    /// relative to the line-fragment box.
    private var systemCaretRect: NSRect = .zero

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    deinit {
        blinkTimer?.invalidate()
    }

    private func commonInit() {
        disableModernInsertionIndicatorIfPossible()
        startBlinkTimer()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        disableModernInsertionIndicatorIfPossible()
        hideModernInsertionIndicatorViews()
        startBlinkTimer()
        setNeedsDisplay(bounds)
    }

    override func layout() {
        super.layout()
        hideModernInsertionIndicatorViews()
    }

    override func updateInsertionPointStateAndRestartTimer(_ restartFlag: Bool) {
        super.updateInsertionPointStateAndRestartTimer(restartFlag)
        hideModernInsertionIndicatorViews()
        if restartFlag {
            blinkOn = true
        }
        invalidateCursor()
    }

    override func setSelectedRanges(
        _ ranges: [NSValue],
        affinity: NSSelectionAffinity,
        stillSelecting flag: Bool
    ) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: flag)
        hideModernInsertionIndicatorViews()
        blinkOn = true
        invalidateCursor()
    }

    override func didChangeText() {
        super.didChangeText()
        hideModernInsertionIndicatorViews()
        blinkOn = true
        invalidateCursor()
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        disableModernInsertionIndicatorIfPossible()
        hideModernInsertionIndicatorViews()
        blinkOn = true
        startBlinkTimer()
        invalidateCursor()
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        invalidateCursor()
        return result
    }

    @objc(_useTextInsertionIndicator)
    func useTextInsertionIndicator() -> Bool {
        false
    }

    /// Capture AppKit's caret geometry (especially Y/height), but do not draw the thin caret.
    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        systemCaretRect = rect
        // no-op drawing — block is painted in draw(_:)
        if flag {
            invalidateCursor()
        }
    }

    @objc(_drawInsertionPointInRect:color:)
    func drawInsertionPointInRect(_ rect: NSRect, color: NSColor) {
        systemCaretRect = rect
        invalidateCursor()
    }

    override func draw(_ dirtyRect: NSRect) {
        hideModernInsertionIndicatorViews()
        super.draw(dirtyRect)

        guard blinkOn,
              window != nil,
              window?.firstResponder === self,
              isEditable,
              selectedRange().length == 0,
              let block = currentBlockRect()
        else {
            return
        }

        blockCursorColor.setFill()
        block.fill()
        drawInvertedGlyph(in: block)
        lastDrawnBlock = block
    }

    // MARK: - Geometry

    private func currentBlockRect() -> NSRect? {
        let font = self.font ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let cellWidth = max(("M" as NSString).size(withAttributes: attributes).width, 2)

        // Prefer AppKit's caret rect for vertical placement — that matches glyph
        // alignment. We only widen it into a C64 character cell.
        if systemCaretRect.width > 0 || systemCaretRect.height > 0 {
            var block = systemCaretRect
            block.size.width = cellWidth
            // Keep AppKit's caret height; it already matches the line's text box.
            if block.size.height < 1 {
                block.size.height = max(font.ascender - font.descender, font.pointSize * 0.8)
            }
            return block.integral
        }

        return fallbackBlockRect(cellWidth: cellWidth, font: font)
    }

    /// Used before AppKit has delivered a caret rect (e.g. first frame).
    private func fallbackBlockRect(cellWidth: CGFloat, font: NSFont) -> NSRect? {
        guard let layoutManager, let textContainer else { return nil }

        let cellHeight = layoutManager.defaultLineHeight(for: font)
        let origin = textContainerOrigin
        let index = selectedRange().location
        let textLength = textStorage?.length ?? 0

        if textLength == 0 {
            return NSRect(
                x: origin.x + textContainer.lineFragmentPadding,
                y: origin.y,
                width: cellWidth,
                height: cellHeight
            ).integral
        }

        let probeIndex = min(index, max(textLength - 1, 0))
        let glyphIndex = layoutManager.glyphIndexForCharacter(at: probeIndex)
        var effectiveRange = NSRange(location: 0, length: 0)
        let lineRect = layoutManager.lineFragmentUsedRect(
            forGlyphAt: glyphIndex,
            effectiveRange: &effectiveRange
        )
        // Used-rect is tighter to the ink than the full line-fragment box, which
        // avoids the block sitting too low in the line spacing gap.
        let caretLocation = layoutManager.location(forGlyphAt: glyphIndex)

        if index >= textLength {
            let lastCharacter = (string as NSString).character(at: max(textLength - 1, 0))
            if lastCharacter == 10 || lastCharacter == 13 {
                return NSRect(
                    x: origin.x + textContainer.lineFragmentPadding,
                    y: origin.y + lineRect.maxY,
                    width: cellWidth,
                    height: cellHeight
                ).integral
            }
            let glyphRect = layoutManager.boundingRect(
                forGlyphRange: NSRange(location: glyphIndex, length: 1),
                in: textContainer
            )
            return NSRect(
                x: origin.x + glyphRect.maxX,
                y: origin.y + lineRect.minY,
                width: cellWidth,
                height: max(lineRect.height, cellHeight * 0.85)
            ).integral
        }

        return NSRect(
            x: origin.x + lineRect.minX + caretLocation.x,
            y: origin.y + lineRect.minY,
            width: cellWidth,
            height: max(lineRect.height, cellHeight * 0.85)
        ).integral
    }

    private func drawInvertedGlyph(in block: NSRect) {
        let location = selectedRange().location
        let nsString = string as NSString
        guard location < nsString.length else { return }

        let glyphRange = nsString.rangeOfComposedCharacterSequence(at: location)
        let character = nsString.substring(with: glyphRange)
        guard character != "\n", character != "\r", !character.isEmpty else { return }

        let font = self.font ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: cursorGlyphColor
        ]
        let glyphSize = (character as NSString).size(withAttributes: attributes)
        let drawPoint = NSPoint(
            x: block.origin.x,
            y: block.origin.y + max((block.height - glyphSize.height) / 2, 0)
        )
        (character as NSString).draw(at: drawPoint, withAttributes: attributes)
    }

    private func invalidateCursor() {
        if !lastDrawnBlock.isEmpty {
            setNeedsDisplay(lastDrawnBlock.insetBy(dx: -2, dy: -2))
        }
        if let block = currentBlockRect() {
            setNeedsDisplay(block.insetBy(dx: -2, dy: -2))
        }
    }

    // MARK: - Blink

    private func startBlinkTimer() {
        blinkTimer?.invalidate()
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.53, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard self.window?.firstResponder === self, self.selectedRange().length == 0 else {
                if self.blinkOn {
                    self.blinkOn = false
                    self.invalidateCursor()
                }
                return
            }
            self.blinkOn.toggle()
            self.invalidateCursor()
        }
        if let blinkTimer {
            RunLoop.main.add(blinkTimer, forMode: .common)
        }
    }

    // MARK: - Modern indicator suppression

    private func disableModernInsertionIndicatorIfPossible() {
        let selector = NSSelectorFromString("_setUseTextInsertionIndicator:")
        if responds(to: selector) {
            typealias Setter = @convention(c) (AnyObject, Selector, Bool) -> Void
            let imp = method(for: selector)
            let cast = unsafeBitCast(imp, to: Setter.self)
            cast(self, selector, false)
        }
        hideModernInsertionIndicatorViews()
    }

    private func hideModernInsertionIndicatorViews() {
        hideInsertionIndicators(in: self)
        if let scrollView = enclosingScrollView {
            hideInsertionIndicators(in: scrollView)
            hideInsertionIndicators(in: scrollView.contentView)
        }
        if let window {
            hideInsertionIndicators(in: window.contentView)
        }
    }

    private func hideInsertionIndicators(in root: NSView?) {
        guard let root else { return }
        var stack: [NSView] = [root]
        while let view = stack.popLast() {
            if let indicator = view as? NSTextInsertionIndicator {
                indicator.displayMode = .hidden
                indicator.isHidden = true
                indicator.alphaValue = 0
                indicator.frame.size = .zero
            } else {
                let typeName = String(describing: type(of: view))
                if typeName.contains("InsertionIndicator") {
                    view.isHidden = true
                    view.alphaValue = 0
                }
            }
            stack.append(contentsOf: view.subviews)
        }
    }
}
