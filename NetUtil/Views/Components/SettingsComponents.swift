import SwiftUI

struct CompactSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String
    var tint: Color = .accentColor

    var body: some View {
        HStack(spacing: 8) {
            Slider(value: $value, in: range, step: step)
                .tint(tint)
                .frame(width: 120)
                .accessibilityLabel("Adjust value")
            Text(String(format: format, value))
                .font(.system(.callout, design: .monospaced))
                .foregroundColor(.primary)
                .frame(width: 58, alignment: .trailing)
                .accessibilityValue(String(format: format, value))
        }
    }
}

struct RTTPreviewBar: View {
    let warn: Double
    let crit: Double

    var body: some View {
        GeometryReader { geo in
            let cap      = max(crit * 1.3, 200.0)
            let warnFrac = CGFloat(min(warn, cap) / cap)
            let critFrac = CGFloat((min(crit, cap) - min(warn, cap)) / cap)
            let redFrac  = max(0, 1 - warnFrac - critFrac)
            HStack(spacing: 0) {
                Rectangle().fill(Color.green.opacity(0.75)).frame(width: geo.size.width * warnFrac)
                Rectangle().fill(Color.orange.opacity(0.75)).frame(width: geo.size.width * critFrac)
                Rectangle().fill(Color.red.opacity(0.75)).frame(width: geo.size.width * redFrac)
            }
        }
        .frame(height: 8)
        .clipShape(Capsule())
        .animation(.easeInOut(duration: 0.25), value: warn)
        .animation(.easeInOut(duration: 0.25), value: crit)
        .accessibilityLabel("RTT Color Zone Preview")
    }
}
