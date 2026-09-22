import SwiftUI
import ThreemaFramework

struct LocalBackupLearnMoreView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let model: LocalBackupLearnMoreViewModel

    private let iconSize: CGFloat = 110

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: horizontalAlignment, spacing: 12) {
                    Image(
                        ImageResource(
                            name: model.iconImageName,
                            bundle: .main
                        )
                    )
                    .frame(width: iconSize, height: iconSize)
                    .padding(.bottom, 40)
                    .accessibilityHidden(true)

                    Text(model.title)
                        .multilineTextAlignment(textAlignment)
                        .font(.largeTitle.bold())

                    Text(model.content)
                        .multilineTextAlignment(textAlignment)
                        .font(.body)
                }
                .frame(maxWidth: .infinity)
                .safeAreaPadding(.horizontal, 44)
            }
            .scrollIndicators(.hidden)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    DoneButton {
                        dismiss()
                    }
                }
            }
        }
    }

    private var horizontalAlignment: HorizontalAlignment {
        dynamicTypeSize >= .accessibility1 ? .leading : .center
    }

    private var textAlignment: TextAlignment {
        dynamicTypeSize >= .accessibility1 ? .leading : .center
    }
}

#if DEBUG
    #Preview(LocalBackupLearnMoreView.Stance.learnMore.title) {
        LocalBackupLearnMoreView.Stance.learnMore.view
    }

    extension LocalBackupLearnMoreView {
        enum Stance: PreviewCase {
            case learnMore

            var title: String {
                switch self {
                case .learnMore: "Backup Center - Local Learn More"
                }
            }

            @MainActor var view: some View {
                switch self {
                case .learnMore:
                    LocalBackupLearnMoreView(
                        model: LocalBackupLearnMoreViewModel()
                    )
                }
            }
        }
    }
#endif
