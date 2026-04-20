import SwiftUI
import ThreemaMacros

struct MultiDeviceWizardSuccessView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 5) {
            Spacer()

            Image("PartyPopper")
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)
                .padding(50)
                .accessibilityHidden(true)
            
            Text(#localize("md_wizard_success_title"))
                .font(.title)
                .bold()
                .multilineTextAlignment(.center)
            
            Text(String.localizedStringWithFormat(
                #localize("md_wizard_success_text"),
                TargetManager.localizedAppName
            ))
            .multilineTextAlignment(.center)

            Spacer()
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Text(#localize("md_wizard_close"))
                    .bold()
            }
            .buttonStyle(.borderedProminent)
            .navigationBarBackButtonHidden()
        }
    }
}

// MARK: - Preview

struct MultiDeviceWizardSuccessView_Previews: PreviewProvider {
    static var previews: some View {
        MultiDeviceWizardSuccessView()
    }
}
