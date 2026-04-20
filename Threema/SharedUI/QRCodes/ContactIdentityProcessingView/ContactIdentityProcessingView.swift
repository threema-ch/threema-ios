import SwiftUI
import ThreemaMacros

struct ContactIdentityProcessingView: View {
    @Bindable var model: ContactIdentityProcessingViewModel

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
            Text(#localize("contact_identity_processing"))
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.thinMaterial)
        .navigationBarBackButtonHidden()
        .interactiveDismissDisabled()
        .onAppear {
            model.onAppear()
        }
        .alert(item: $model.alert) { alertData in
            Alert(
                title: Text(alertData.title),
                message: alertData.message.map { Text($0) },
                dismissButton: .default(Text(#localize("ok"))) {
                    model.alertOKButtonTapped()
                }
            )
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                XMarkCancelButton {
                    model.onCompletion?(nil)
                }
            }
        }
    }
}

#Preview {
    ContactIdentityProcessingView(
        model: ContactIdentityProcessingViewModel(
            expectedIdentity: nil,
            scannedIdentity: .init(rawValue: "A123456"),
            scannedPublicKey: Data(),
            scannedExpirationDate: nil,
            systemFeedbackManager: .null
        )
    )
}
