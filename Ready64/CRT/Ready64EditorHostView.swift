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
        // C64 blue — never pure black under the CRT overlay / during fallback.
        layer?.backgroundColor = Ready64Theme.classic.screenBackground.cgColor

        scrollView.translatesAutoresizingMaskIntoConstraints = true
        scrollView.autoresizingMask = [.width, .height]
        // Keep the live editor drawing even when covered by the Metal overlay.
        scrollView.wantsLayer = true
        scrollView.layerContentsRedrawPolicy = .duringViewResize
        if let document = scrollView.documentView {
            document.wantsLayer = true
            document.layerContentsRedrawPolicy = .duringViewResize
        }

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
        // Keep live editor above a failed/hidden CRT path for hit-testing/compositing.
        if crtView.isHidden {
            scrollView.layer?.zPosition = 1
            crtView.layer?.zPosition = 0
        } else {
            scrollView.layer?.zPosition = 0
            crtView.layer?.zPosition = 1
        }
    }

    private func applyCRTState() {
        crtView.parameters = crtParameters
        crtView.effectActive = crtParameters.isActive
    }
}
