import SwiftUI

struct BackupHeaderView: View {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @ScaledMetric private var scaledMetric: CGFloat = 1.0

    let step: String?
    let title: String?
    let subtitle: String?

    /// Color drawn inside the glyphs, behind the (partly translucent) label colors.
    ///
    /// Pass the color the header sits on whenever it overlaps decorative content such as `DotHeaderView`, otherwise
    /// that content shines through the letters. `nil` keeps the text fully translucent.
    var backdrop: Color?

    var body: some View {
        VStack(alignment: alignment, spacing: 16) {
            if let step {
                text(step)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if let title {
                text(title)
                    .font(.title.bold())
                    .foregroundStyle(.primary)
            }

            if let subtitle {
                text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(textAlignment)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
    }

    /// Text with an opaque copy of itself underneath, so nothing behind the header is visible through the glyphs.
    ///
    /// The copy is drawn as a background and therefore inherits font, alignment and line limits from the modifiers
    /// applied to the returned view, which keeps both copies laid out identically.
    private func text(_ value: String) -> some View {
        Text(value)
            .background {
                if let backdrop {
                    Text(value)
                        .foregroundStyle(backdrop)
                }
            }
    }

    private var alignment: HorizontalAlignment {
        dynamicTypeSize >= .accessibility3 ? .leading : .center
    }

    private var textAlignment: TextAlignment {
        dynamicTypeSize >= .accessibility3 ? .leading : .center
    }
}

#if DEBUG
    #Preview {
        Color(.white).ignoresSafeArea()
            .overlay {
                ScrollView {
                    VStack(spacing: 24) {
                        BackupHeaderView(
                            step: "STEP 1 OF 4",
                            title: "Creating backup",
                            subtitle: "This may take a few minutes depending on your backup size."
                        )
                        .border(.primary, width: 0.3)
                    }
                }
                .scrollIndicators(.hidden)
                .padding()
                .ignoresSafeArea(edges: [.bottom])
            }
    }
#endif
