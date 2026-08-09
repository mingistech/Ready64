import Foundation

/// Persisted Ready64 preferences.
enum Ready64Settings {
    static let typefaceKey = "editorTypeface"
    static let insertStartupBannerKey = "insertStartupBanner"

    // cool-retro-term Effects tab keys (raw 0…1 slider values)
    static let crtBloomKey = "crtBloom"
    static let crtBurnInKey = "crtBurnIn"
    static let crtStaticNoiseKey = "crtStaticNoise"
    static let crtJitterKey = "crtJitter"
    static let crtGlowLineKey = "crtGlowLine"
    static let crtAmbientLightKey = "crtAmbientLight"
    static let crtFlickeringKey = "crtFlickering"
    static let crtHorizontalSyncKey = "crtHorizontalSync"
    static let crtRgbShiftKey = "crtRgbShift"
    static let crtFrameShininessKey = "crtFrameShininess"
    static let crtContrastKey = "crtContrast"
    static let crtSaturationKey = "crtSaturation"

    static var defaultTypeface: Ready64Typeface { .commodore64 }
    static var defaultCRT: CRTEffectParameters { .default }

    /// Reads the startup-banner preference for new-document creation.
    static var insertStartupBanner: Bool {
        UserDefaults.standard.bool(forKey: insertStartupBannerKey)
    }

    /// Assembles CRT parameters from UserDefaults (missing keys → cool-retro-term defaults).
    static var crtParameters: CRTEffectParameters {
        let defaults = UserDefaults.standard
        let base = CRTEffectParameters.default
        return CRTEffectParameters(
            bloom: float(defaults, key: crtBloomKey, fallback: base.bloom),
            burnIn: float(defaults, key: crtBurnInKey, fallback: base.burnIn),
            staticNoise: float(defaults, key: crtStaticNoiseKey, fallback: base.staticNoise),
            jitter: float(defaults, key: crtJitterKey, fallback: base.jitter),
            glowingLine: float(defaults, key: crtGlowLineKey, fallback: base.glowingLine),
            ambientLight: float(defaults, key: crtAmbientLightKey, fallback: base.ambientLight),
            flickering: float(defaults, key: crtFlickeringKey, fallback: base.flickering),
            horizontalSync: float(defaults, key: crtHorizontalSyncKey, fallback: base.horizontalSync),
            rgbShift: float(defaults, key: crtRgbShiftKey, fallback: base.rgbShift),
            frameShininess: float(defaults, key: crtFrameShininessKey, fallback: base.frameShininess),
            contrast: float(defaults, key: crtContrastKey, fallback: base.contrast),
            saturation: float(defaults, key: crtSaturationKey, fallback: base.saturation)
        )
    }

    private static func float(_ defaults: UserDefaults, key: String, fallback: Float) -> Float {
        guard defaults.object(forKey: key) != nil else { return fallback }
        return Float(defaults.double(forKey: key))
    }
}
