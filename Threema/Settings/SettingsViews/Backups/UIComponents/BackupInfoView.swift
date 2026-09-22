import SwiftUI

struct BackupInfoView: View {
    @ScaledMetric var scaledMetric: CGFloat = 1
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    let title: String?
    let content: String?
    let textColor: Color
    let textFont: Font
    let iconName: String
    let iconColor: Color

    var body: some View {
        if title != nil || content != nil {
            HStack(alignment: .top, spacing: 4) {
                if !dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: iconName)
                        .fontWeight(.semibold)
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading) {
                    if let title {
                        Text(
                            (try? AttributedString(
                                markdown: title
                            )) ?? AttributedString(title)
                        )
                        .font(textFont)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let content {
                        Text((try? AttributedString(markdown: content)) ?? AttributedString(content))
                            .font(textFont)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .foregroundStyle(textColor)
            }
            .padding(10 * scaledMetric)
            .background(iconColor.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 12 * scaledMetric))
            .listRowBackground(Color.clear)
        }
    }
}

#if DEBUG
    #Preview {
        VStack {
            BackupInfoView(
                title: nil,
                content: "**Important**: This is an important information",
                textColor: Color.accentColor,
                textFont: .callout,
                iconName: "info.circle",
                iconColor: Color.accentColor,
            )
            .padding()

            BackupInfoView(
                title: "Title of the reason",
                content: "~Description~ of the reason",
                textColor: Color.red,
                textFont: .callout,
                iconName: "exclamationmark.circle",
                iconColor: Color.red
            )
            .padding()

            BackupInfoView(
                title: "Never share this key with anyone",
                content: "Anyone with it can restore your encrypted backup and read your messages",
                textColor: Color.primary,
                textFont: .callout,
                iconName: "info.circle",
                iconColor: Color.accentColor
            )
            .padding()
        }
    }
#endif
