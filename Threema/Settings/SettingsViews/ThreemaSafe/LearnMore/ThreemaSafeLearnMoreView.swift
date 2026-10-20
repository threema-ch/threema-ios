import SwiftUI

struct ThreemaSafeLearnMoreView: View {
    @Environment(\.dismiss) private var dismiss

    let model: ThreemaSafeLearnMoreViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text(model.title)
                        .font(.title2).bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)

                    Text(model.content)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .multilineTextAlignment(.leading)
                .padding(24)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    DoneButton {
                        dismiss()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#if DEBUG
    #Preview(ThreemaSafeLearnMoreView.Stance.learnMore.title) {
        ThreemaSafeLearnMoreView.Stance.learnMore.view
    }

    extension ThreemaSafeLearnMoreView {
        enum Stance: PreviewCase {
            case learnMore

            var title: String {
                switch self {
                case .learnMore: "Backup Center - Threema Safe Learn More"
                }
            }

            @MainActor var view: some View {
                switch self {
                case .learnMore:
                    ThreemaSafeLearnMoreView(model: .init(appFlavor: .blue))
                }
            }
        }
    }
#endif
