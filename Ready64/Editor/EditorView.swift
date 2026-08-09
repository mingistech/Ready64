import SwiftUI

/// Document window contents: C64 presentation chrome around the NSTextView editor.
struct EditorView: View {
    @Binding var document: TextDocument

    @AppStorage(Ready64Settings.typefaceKey)
    private var typefaceRaw = Ready64Settings.defaultTypeface.rawValue

    @AppStorage(Ready64Settings.crtBloomKey)
    private var bloom = Double(CRTEffectParameters.default.bloom)

    @AppStorage(Ready64Settings.crtBurnInKey)
    private var burnIn = Double(CRTEffectParameters.default.burnIn)

    @AppStorage(Ready64Settings.crtStaticNoiseKey)
    private var staticNoise = Double(CRTEffectParameters.default.staticNoise)

    @AppStorage(Ready64Settings.crtJitterKey)
    private var jitter = Double(CRTEffectParameters.default.jitter)

    @AppStorage(Ready64Settings.crtGlowLineKey)
    private var glowingLine = Double(CRTEffectParameters.default.glowingLine)

    @AppStorage(Ready64Settings.crtAmbientLightKey)
    private var ambientLight = Double(CRTEffectParameters.default.ambientLight)

    @AppStorage(Ready64Settings.crtFlickeringKey)
    private var flickering = Double(CRTEffectParameters.default.flickering)

    @AppStorage(Ready64Settings.crtHorizontalSyncKey)
    private var horizontalSync = Double(CRTEffectParameters.default.horizontalSync)

    @AppStorage(Ready64Settings.crtRgbShiftKey)
    private var rgbShift = Double(CRTEffectParameters.default.rgbShift)

    @AppStorage(Ready64Settings.crtFrameShininessKey)
    private var frameShininess = Double(CRTEffectParameters.default.frameShininess)

    @AppStorage(Ready64Settings.crtContrastKey)
    private var contrast = Double(CRTEffectParameters.default.contrast)

    @AppStorage(Ready64Settings.crtSaturationKey)
    private var saturation = Double(CRTEffectParameters.default.saturation)

    private let theme = Ready64Theme.current

    private var typeface: Ready64Typeface {
        Ready64Typeface(rawValue: typefaceRaw) ?? Ready64Settings.defaultTypeface
    }

    private var crtParameters: CRTEffectParameters {
        CRTEffectParameters(
            bloom: Float(bloom),
            burnIn: Float(burnIn),
            staticNoise: Float(staticNoise),
            jitter: Float(jitter),
            glowingLine: Float(glowingLine),
            ambientLight: Float(ambientLight),
            flickering: Float(flickering),
            horizontalSync: Float(horizontalSync),
            rgbShift: Float(rgbShift),
            frameShininess: Float(frameShininess),
            contrast: Float(contrast),
            saturation: Float(saturation)
        )
    }

    var body: some View {
        ZStack {
            theme.borderColor

            Ready64TextView(
                text: $document.text,
                theme: theme,
                font: Ready64Font.editorFont(typeface: typeface),
                crtParameters: crtParameters
            )
            .padding(Ready64Layout.borderWidth)
        }
        .ignoresSafeArea()
        .background(WindowChromeConfigurator())
        .toolbarBackground(.hidden, for: .windowToolbar)
        .navigationTitle("")
        .modifier(HideToolbarTitleModifier())
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
