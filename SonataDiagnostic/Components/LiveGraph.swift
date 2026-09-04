import SwiftUI

struct LiveGraph: View {
    let values: [Double]?
    let color: Color
    var body: some View {
        GeometryReader { proxy in
            if let values, values.count > 1, let low = values.min(), let high = values.max() {
                Path { path in
                    let span = max(high - low, 0.01)
                    for (index, value) in values.enumerated() {
                        let x = proxy.size.width * CGFloat(index) / CGFloat(values.count - 1)
                        let y = proxy.size.height * (1 - CGFloat((value - low) / span))
                        if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }.stroke(color, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
            } else {
                HStack(spacing: 4) { Image(systemName: "waveform.path"); Text("Streaming unavailable") }.font(.caption2).foregroundStyle(SDTheme.muted).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }
        }
    }
}
