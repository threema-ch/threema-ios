import SwiftUI

struct ThreemaSafeLearnMoreView: View {
    @Environment(\.dismiss) private var dismiss

    let model: ThreemaSafeLearnMoreViewModel

    var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text(model.headline)
                        .font(.title2).bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)

                    Text(model.body)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .multilineTextAlignment(.leading)
                .padding(24)
            }
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

#if DEBUG
    #Preview {
        NavigationView {
            ThreemaSafeLearnMoreView(model: .init(appFlavor: .onPrem))
        }
    }
#endif
