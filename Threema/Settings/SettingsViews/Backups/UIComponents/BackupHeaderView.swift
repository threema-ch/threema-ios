import SwiftUI

struct BackupHeaderView: View {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @ScaledMetric private var scaledMetric: CGFloat = 1.0

    let icon: Icon?
    let step: String?
    let title: String?
    let subtitle: String?

    var body: some View {
        VStack(alignment: alignment, spacing: 16) {
            if let icon {
                Image(systemName: icon.symbolName)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white)
                    .frame(width: 22 * scaledMetric, height: 22 * scaledMetric)
                    .rotationEffect(.degrees(icon.rotationDegrees))
                    .frame(width: 48 * scaledMetric, height: 48 * scaledMetric)
                    .background(icon.color, in: .circle)
            }

            if let step {
                Text(step)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            if let title {
                Text(title)
                    .font(.title.bold())
                    .foregroundStyle(.primary)
            }

            if let subtitle {
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(textAlignment)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
    }

    private var alignment: HorizontalAlignment {
        dynamicTypeSize >= .accessibility3 ? .leading : .center
    }

    private var textAlignment: TextAlignment {
        dynamicTypeSize >= .accessibility3 ? .leading : .center
    }

    struct Icon {
        let symbolName: String
        let color: Color
        let rotationDegrees: Double

        init(symbolName: String, color: Color, rotationDegrees: Double = 0) {
            self.symbolName = symbolName
            self.color = color
            self.rotationDegrees = rotationDegrees
        }
    }
}

#if DEBUG
    #Preview {
        Color(.white).ignoresSafeArea()
            .overlay {
                ScrollView {
                    VStack(spacing: 24) {
                        ForEach(
                            [
                                (1, "key.fill", Color.blue, 30.0),
                                (2, "gearshape.fill", Color.blue, 0.0),
                                (3, "arrow.trianglehead.2.counterclockwise.rotate.90", Color.blue, 0.0),
                                (4, "checkmark", Color.green, 0.0),
                                (5, "exclamationmark", Color.red, 0.0)
                            ] as [(Int, String, Color, Double)], id: \.0
                        ) { item in
                            BackupHeaderView(
                                icon: .init(symbolName: item.1, color: item.2, rotationDegrees: item.3),
                                step: "STEP 1 OF 4",
                                title: "Creating backup",
                                subtitle: "This may take a few minutes depending on your backup size."
                            )
                            .border(.primary, width: 0.3)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .padding()
                .ignoresSafeArea(edges: [.bottom])
            }
    }
#endif
