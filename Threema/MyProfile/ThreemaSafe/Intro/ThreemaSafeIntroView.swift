import SwiftUI
import ThreemaFramework

struct ThreemaSafeIntroView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @ScaledMetric var dynamicPadding: CGFloat = 10

    let model: ThreemaSafeIntroViewModel
    private let accessibilityThreshold = DynamicTypeSize.xxLarge

    var body: some View {
        ScrollView {
            VStack {
                Text(model.title)
                    .font(.title).bold()
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.bottom, dynamicPadding)

                Text(model.description)
                    .font(.title3)
                    .multilineTextAlignment(.center)

                Image(model.threemaSafeIcon)
                    .resizable()
                    .frame(width: 13 * dynamicPadding, height: 13 * dynamicPadding)
                    .scaledToFit()
                    .clipShape(.circle)
                    .padding(.bottom, dynamicPadding)

                GroupBox {
                    Text(model.explain)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, dynamicPadding)

                if dynamicTypeSize >= accessibilityThreshold {
                    ButtonsView(model: model)
                        .padding(.top, dynamicPadding)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .toolbar(.hidden)
        .safeAreaPadding(EdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24))
        .scrollBounceBehavior(.basedOnSize)
        .overlay(alignment: .bottom) {
            if dynamicTypeSize < accessibilityThreshold {
                ButtonsView(model: model)
                    .padding(24)
            }
        }
        .onChange(of: model.shouldDismiss) {
            if model.shouldDismiss {
                dismiss()
            }
        }
    }

    struct ButtonsView: View {
        @ScaledMetric var spacing: CGFloat = 10
        let model: ThreemaSafeIntroViewModel

        var body: some View {
            VStack(spacing: spacing) {
                ThreemaButton(
                    title: model.enableButtonTitle, style: .borderedProminent, size: .fullWidth
                ) {
                    model.confirmationButtonTapped()
                }

                ThreemaButton(
                    title: model.cancelButtonTitle, role: .destructive, style: .bordered, size: .fullWidth
                ) {
                    model.cancelButtonTapped()
                }
            }
            .onAppear {
                model.onAppear()
            }
        }
    }
}

#if DEBUG
    #Preview {
        ThreemaSafeIntroView(model: ThreemaSafeIntroViewModel(appFlavor: .mock, userSettings: .mock))
    }
#endif
