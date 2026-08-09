import AppKit
import Metal
import MetalKit

/// Hosts the scrolling NSTextView and an optional CRT Metal overlay.
final class Ready64EditorHostView: NSView {
    let scrollView: NSScrollView
    let crtView: CRTEffectView

    var crtParameters = CRTEffectParameters.default {
        didSet { applyCRTState() }
    }

    init(scrollView: NSScrollView) {
        self.scrollView = scrollView
        self.crtView = CRTEffectView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        scrollView.translatesAutoresizingMaskIntoConstraints = true
        scrollView.autoresizingMask = [.width, .height]

        crtView.translatesAutoresizingMaskIntoConstraints = true
        crtView.autoresizingMask = [.width, .height]
        crtView.sourceView = scrollView

        addSubview(scrollView)
        addSubview(crtView)
        applyCRTState()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        scrollView.frame = bounds
        crtView.frame = bounds
    }

    private func applyCRTState() {
        crtView.parameters = crtParameters
        crtView.effectActive = crtParameters.isActive
    }
}
