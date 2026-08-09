import Foundation

/// Raw 0…1 CRT effect sliders matching cool-retro-term’s Effects tab.
///
/// Shader uniforms apply the same scaling as `ShaderTerminal.qml` /
/// `ApplicationSettings.qml` in cool-retro-term.
///
/// Screen curvature is intentionally omitted — without a CRT bezel it only
/// crops usable editing space.
struct CRTEffectParameters: Equatable, Sendable {
    /// Bloom (UI 0…1 → uniform `bloom * 2.5`).
    var bloom: Float
    /// Phosphor persistence (UI 0…1).
    var burnIn: Float
    /// Static noise (passed through).
    var staticNoise: Float
    /// Screen jitter (UI 0…1).
    var jitter: Float
    /// Moving glow / refresh line (UI 0…1 → uniform `* 0.2`).
    var glowingLine: Float
    /// Ambient light on bezel/edges (UI 0…1 → uniform `* 0.2`).
    var ambientLight: Float
    /// Brightness flicker (passed through).
    var flickering: Float
    /// Horizontal sync tear (UI 0…1 → strength `lint(0.05, 0.35, value)`).
    var horizontalSync: Float
    /// Chromatic aberration (UI 0…1 → `* (4/width) * fontScaling`).
    var rgbShift: Float
    /// Frame / edge shininess (UI `_frameShininess` 0…1 → uniform `* 0.5`).
    var frameShininess: Float
    /// Contrast (UI 0…1; cool-retro-term General default `0.80`).
    var contrast: Float
    /// Saturation (UI 0…1; cool-retro-term `saturationColor` default `0.25`).
    var saturation: Float

    /// cool-retro-term `ApplicationSettings` defaults (minus curvature).
    static let `default` = CRTEffectParameters(
        bloom: 0.55,
        burnIn: 0.25,
        staticNoise: 0.12,
        jitter: 0.20,
        glowingLine: 0.20,
        ambientLight: 0.20,
        flickering: 0.10,
        horizontalSync: 0.08,
        rgbShift: 0.0,
        frameShininess: 0.20,
        contrast: 0.80,
        saturation: 0.25
    )

    /// Any non-zero effect means the CRT overlay should run.
    var isActive: Bool {
        bloom > 0 || burnIn > 0 || staticNoise > 0 || jitter > 0
            || glowingLine > 0 || ambientLight > 0
            || flickering > 0 || horizontalSync > 0 || rgbShift > 0
            || frameShininess > 0 || contrast > 0 || saturation > 0
    }

    // MARK: - cool-retro-term uniform scaling

    static let minBurnInFadeTime: Float = 0.16
    static let maxBurnInFadeTime: Float = 1.6
    /// Approximate `baseFontScaling * fontScaling` when font scaling is 1.
    static let totalFontScaling: Float = 0.75
    /// Downsample factor for the bloom buffer (higher = sharper / tighter glow).
    static let bloomQuality: Float = 0.65

    static func lint(_ a: Float, _ b: Float, _ t: Float) -> Float {
        (1 - t) * a + t * b
    }

    /// Separable blur radius in bloom-buffer texels.
    /// Slightly wider than the tight pass so the halo extends past glyph edges
    /// without washing the whole screen.
    static var bloomBlurRadius: Float {
        lint(14, 32, bloomQuality)
    }

    /// `1024 / ((0.5 * width + 0.5 * height))`
    static func normalizedWindowScale(width: Float, height: Float) -> Float {
        1024.0 / max(0.5 * width + 0.5 * height, 1)
    }

    var scaledBloom: Float { bloom * 2.5 }

    var scaledGlowingLine: Float { glowingLine * 0.2 }

    var scaledAmbientLight: Float { ambientLight * 0.2 }

    /// Matches `frameShininess: _frameShininess * 0.5`.
    var scaledFrameShininess: Float { frameShininess * 0.5 }

    var burnInFadeTime: Float {
        guard burnIn > 0 else { return 0 }
        return 1.0 / Self.lint(Self.minBurnInFadeTime, Self.maxBurnInFadeTime, burnIn)
    }

    var horizontalSyncStrength: Float {
        Self.lint(0.05, 0.35, horizontalSync)
    }

    func scaledRgbShift(width: Float) -> Float {
        rgbShift * (4.0 / max(width, 1)) * Self.totalFontScaling
    }

    func jitterDisplacement() -> SIMD2<Float> {
        SIMD2<Float>(0.007 * jitter, 0.002 * jitter)
    }
}
