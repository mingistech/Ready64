import SwiftUI

/// Checkbox + slider + percent label, matching cool-retro-term’s `CheckableSlider`.
///
/// Unchecking forces the value to `0`. Checking restores the slider’s current
/// non-zero position (or a sensible default if it was zero).
struct CheckableSlider: View {
    let name: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var defaultOnValue: Double = 0.2

    @State private var lastNonZero: Double?

    private var isOn: Bool { value > 0.000_01 }

    private var percent: Int {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return Int(((value - range.lowerBound) / span * 100).rounded())
    }

    var body: some View {
        HStack(spacing: 12) {
            Toggle(isOn: Binding(
                get: { isOn },
                set: { enabled in
                    if enabled {
                        let restore = lastNonZero ?? (value > 0 ? value : defaultOnValue)
                        value = min(max(restore, range.lowerBound), range.upperBound)
                        if value <= 0 {
                            value = min(max(defaultOnValue, range.lowerBound), range.upperBound)
                        }
                    } else {
                        if value > 0 {
                            lastNonZero = value
                        }
                        value = 0
                    }
                }
            )) {
                Text(name)
                    .frame(width: 140, alignment: .leading)
            }
            .toggleStyle(.checkbox)

            Slider(value: Binding(
                get: { value },
                set: { newValue in
                    value = newValue
                    if newValue > 0 {
                        lastNonZero = newValue
                    }
                }
            ), in: range)
            .disabled(!isOn)

            Text("\(percent)%")
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
        .onAppear {
            if value > 0 {
                lastNonZero = value
            }
        }
    }
}
