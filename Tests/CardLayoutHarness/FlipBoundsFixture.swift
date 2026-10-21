import SwiftUI

struct FlipBoundsFixture: View {
    @State private var angle: Double = 0
    @State private var cardFrame = CGRect.zero
    @State private var envelopeFrame = CGRect.zero

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach([0, 30, 60, 80, 100, 120, 150, 180], id: \.self) { degrees in
                    Button(String(degrees)) { angle = Double(degrees) }
                        .accessibilityIdentifier("angle-\(degrees)")
                }
            }
            Text(String(format: "%.3f,%.3f,%.3f,%.3f,%.3f",
                        cardFrame.minY - envelopeFrame.minY,
                        envelopeFrame.maxY - cardFrame.maxY,
                        cardFrame.height, envelopeFrame.height, angle))
                .accessibilityIdentifier("flip-bounds")
            Group {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.black)
                    .overlay(alignment: .top) {
                        Rectangle().fill(.green).frame(height: 24)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .frame(width: 352, height: 420)
                    .onGeometryChange(for: CGRect.self) { geometry in
                        geometry.frame(in: .global)
                    } action: { frame in
                        cardFrame = frame
                    }
                    .modifier(PassFlipEffect(angle: angle))
            }
            .onGeometryChange(for: CGRect.self) { geometry in
                geometry.frame(in: .global)
            } action: { frame in
                envelopeFrame = frame
            }
            Spacer(minLength: 0)
        }
    }
}
