import SwiftUI

struct DashboardSparkline: View {
    let data: [Double]
    let color: Color

    var body: some View {
        Canvas { context, size in
            guard data.count > 1 else { return }
            let minVal = data.min() ?? 0
            let maxVal = data.max() ?? 1
            let range  = max(maxVal - minVal, 1.0)
            let stepX  = size.width / CGFloat(data.count - 1)
            var path   = Path()
            for (i, value) in data.enumerated() {
                let x = CGFloat(i) * stepX
                let y = size.height - CGFloat((value - minVal) / range) * size.height
                i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
            }
            context.stroke(path, with: .color(color), lineWidth: 2)
            var fill = path
            fill.addLine(to: CGPoint(x: size.width, y: size.height))
            fill.addLine(to: CGPoint(x: 0, y: size.height))
            fill.closeSubpath()
            context.fill(fill, with: .linearGradient(
                Gradient(colors: [color.opacity(0.15), color.opacity(0.0)]),
                startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: size.height)))
        }
        .accessibilityLabel("Trend sparkline")
    }
}
