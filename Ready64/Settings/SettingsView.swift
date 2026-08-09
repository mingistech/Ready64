import SwiftUI

/// Ready64 > Settings… window.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }

            EffectsSettingsTab()
                .tabItem { Label("Effects", systemImage: "tv") }
        }
        .frame(width: 540, height: 860)
    }
}

// MARK: - General

private struct GeneralSettingsTab: View {
    @AppStorage(Ready64Settings.typefaceKey)
    private var typefaceRaw = Ready64Settings.defaultTypeface.rawValue

    @AppStorage(Ready64Settings.insertStartupBannerKey)
    private var insertStartupBanner = false

    private var typeface: Ready64Typeface {
        Ready64Typeface(rawValue: typefaceRaw) ?? Ready64Settings.defaultTypeface
    }

    var body: some View {
        Form {
            Section {
                Toggle("Insert C64 startup banner in new documents", isOn: $insertStartupBanner)

                StartupBannerPreview(typeface: typeface)
                    .opacity(insertStartupBanner ? 1 : 0.45)

                Text("When enabled, this text is inserted into new documents and will be saved with the file. Existing documents are not changed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("New Documents")
            }

            Section {
                Picker("Editor Font", selection: $typefaceRaw) {
                    ForEach(Ready64Typeface.allCases) { face in
                        Text(face.displayName).tag(face.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)

                Text("The selected font is used for display only and is not saved into your text files.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Appearance")
            }

            Section {
                Text("READY.\n10 PRINT \"HELLO\"\n20 GOTO 10")
                    .font(Font(Ready64Font.editorFont(typeface: typeface) as CTFont))
                    .foregroundStyle(Ready64Theme.current.foregroundColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Ready64Theme.current.screenBackgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } header: {
                Text("Font Preview")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Effects (cool-retro-term one-to-one)

private struct EffectsSettingsTab: View {
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

    var body: some View {
        Form {
            Section {
                CheckableSlider(name: "Bloom", value: $bloom, defaultOnValue: 0.55)
                CheckableSlider(name: "BurnIn", value: $burnIn, defaultOnValue: 0.25)
                CheckableSlider(name: "Static Noise", value: $staticNoise, defaultOnValue: 0.12)
                CheckableSlider(name: "Jitter", value: $jitter, defaultOnValue: 0.20)
                CheckableSlider(name: "Glow Line", value: $glowingLine, defaultOnValue: 0.20)
                CheckableSlider(name: "Ambient Light", value: $ambientLight, defaultOnValue: 0.20)
                CheckableSlider(name: "Flickering", value: $flickering, defaultOnValue: 0.10)
                CheckableSlider(name: "Horizontal Sync", value: $horizontalSync, defaultOnValue: 0.08)
                CheckableSlider(name: "RGB Shift", value: $rgbShift, defaultOnValue: 0.20)
                CheckableSlider(name: "Frame Shininess", value: $frameShininess, defaultOnValue: 0.20)
                CheckableSlider(name: "Contrast", value: $contrast, defaultOnValue: 0.80)
                CheckableSlider(name: "Saturation", value: $saturation, defaultOnValue: 0.25)
            } header: {
                Text("Effects")
            } footer: {
                Text("Slider ranges and scaling match cool-retro-term. Uncheck an effect to set it to 0%. CRT presentation never changes your saved text files.")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

/// Renders each banner line on its own row so leading spaces and line breaks
/// match new documents (no Soft-wrapping of "COMMODORE 64 BASIC V2", etc.).
private struct StartupBannerPreview: View {
    let typeface: Ready64Typeface

    private var lines: [String] {
        var parts = Ready64StartupBanner.text.split(
            separator: "\n",
            omittingEmptySubsequences: false
        ).map(String.init)
        if parts.last?.isEmpty == true {
            parts.removeLast()
        }
        return parts
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(verbatim: line.isEmpty ? " " : line)
                    .font(Font(Ready64Font.editorFont(typeface: typeface, size: 12) as CTFont))
                    .foregroundStyle(Ready64Theme.current.foregroundColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(Ready64Theme.current.screenBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

#Preview {
    SettingsView()
}
