import SwiftUI
import ThreemaFramework

struct StandardHeaderView: View {
    static let defaultHeight: CGFloat = 300
    static let defaultOverlap: CGFloat = 1.0 / 2.8

    let icon: Icon
    var height: CGFloat = Self.defaultHeight

    var body: some View {
        Color.clear
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

    private struct IconBadge: View {
        @ScaledMetric private var scaledMetric: CGFloat = 1.0

        let icon: StandardHeaderView.Icon

        private let imageSize: CGFloat = 20

        var body: some View {
            Image(systemName: icon.name)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
                .frame(width: imageSize * scaledMetric, height: imageSize * scaledMetric)
                .rotationEffect(.degrees(icon.rotationDegrees))
                .frame(width: 48 * scaledMetric, height: 48 * scaledMetric)
                .background(icon.color, in: .circle)
        }
    }
}

#if DEBUG
    #Preview {
        ScrollView {
            StandardHeaderView(
                icon: .init(name: "key.fill", color: .statusForegroundInfo, rotationDegrees: 20)
            )

            Divider()

            StandardHeaderView(
                icon: .init(name: "gearshape.fill", color: .statusForegroundInfo)
            )

            Divider()

            StandardHeaderView(
                icon: .init(name: "checkmark.circle.fill", color: .statusForegroundSuccess)
            )

            Divider()

            StandardHeaderView(
                icon: .init(name: "exclamationmark.circle.fill", color: .statusForegroundDestructive)
            )
        }
    }
#endif
