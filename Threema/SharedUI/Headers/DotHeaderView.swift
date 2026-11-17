import SwiftUI
import ThreemaFramework

struct DotHeaderView: View {
    static let defaultHeight: CGFloat = 350
    static let defaultOverlap: CGFloat = 1.0 / 3.0

    let icon: Icon
    let dotColor: Color
    var height: CGFloat = Self.defaultHeight

    var body: some View {
        DotField(color: dotColor)
            .frame(height: height)
            .overlay {
                IconBadge(icon: icon)
            }
            .accessibilityHidden(true)
    }

    struct Icon {
        let name: String
        let color: Color
        let rotationDegrees: Double

        init(name: String, color: Color, rotationDegrees: Double = 0) {
            self.name = name
            self.color = color
            self.rotationDegrees = rotationDegrees
        }
    }

    private struct DotField: View {
        let color: Color

        private let spacing: CGFloat = 7
        private let dotRadius: CGFloat = 1
        private let falloff: CGFloat = 0.75 // fraction of the short side where dots die out

        var body: some View {
            Canvas { ctx, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let maxDist = min(size.width, size.height) * falloff

                var y = spacing / 2
                while y < size.height {
                    var x = spacing / 2
                    while x < size.width {
                        let d = hypot(x - center.x, y - center.y) / maxDist
                        let t = max(0, 1 - d)
                        let alpha = t * t * (3 - 2 * t) // smooth step, softer edge

                        if alpha > 0.01 {
                            let r = dotRadius * (0.75 + 0.25 * alpha) // slight size taper
                            let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                            ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(alpha)))
                        }
                        x += spacing
                    }
                    y += spacing
                }
            }
        }
    }

    private struct IconBadge: View {
        @ScaledMetric private var scaledMetric: CGFloat = 1.0

        let icon: DotHeaderView.Icon

        private let side: CGFloat = 85
        private let imageSide: CGFloat = 30
        private let straightSideFraction: CGFloat = 1.0 / 7.0

        private var sideLength: CGFloat { side * scaledMetric }
        private var cornerRadius: CGFloat { sideLength * (1 - straightSideFraction) / 2 }

        var body: some View {
            RoundedRectangle(cornerRadius: cornerRadius, style: .circular)
                .fill(Color(.systemBackground))
                .stroke(Color.gray200, lineWidth: 1.5)
                .frame(width: sideLength, height: sideLength)
                .overlay {
                    Image(systemName: icon.name)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(icon.color)
                        .frame(width: imageSide * scaledMetric, height: imageSide * scaledMetric)
                        .fontWeight(.semibold)
                        .rotationEffect(.degrees(icon.rotationDegrees))
                }
        }
    }
}

#if DEBUG
    #Preview {
        ScrollView {
            DotHeaderView(
                icon: .init(name: "key", color: .accentColor),
                dotColor: .accentColor.opacity(0.3)
            )

            Divider()

            DotHeaderView(
                icon: .init(name: "gearshape", color: .accentColor),
                dotColor: .accentColor.opacity(0.3)
            )

            Divider()

            DotHeaderView(
                icon: .init(name: "checkmark.circle", color: .green),
                dotColor: .accentColor
            )

            Divider()

            DotHeaderView(
                icon: .init(name: "exclamationmark.circle", color: .red),
                dotColor: .red
            )
        }
    }
#endif
