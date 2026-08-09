import SwiftUI

/// Ready64 > Settings… window.
struct SettingsView: View {
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
        .frame(width: 460, height: 720)
        .padding()
    }
}

/// Renders each banner line on its own row so leading spaces and line breaks
/// match new documents (no Soft-wrapping of "COMMODORE 64 BASIC V2", etc.).
private struct StartupBannerPreview: View {
    let typeface: Ready64Typeface

    private var lines: [String] {
        // Keep empty lines for vertical spacing; drop a single trailing empty
        // entry produced by the final newline in the banner string.
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
