import SwiftUI
import ThreemaFramework
import ThreemaMacros

struct LinkEmailVerifyView: View {
    @ObservedObject var viewModel: LinkEmailViewModel
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text(#localize("link_email_textfield_placeholder"))
                    Spacer()
                    Text(viewModel.email)
                }
            }
            footer: {
                HStack {
                    ThreemaButton(
                        title: #localize("profile_code_abort_verification"),
                        role: .destructive,
                        style: .bordered,
                        size: .small
                    ) {
                        viewModel.showAbortVerificationAlert = true
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity)
            }
        }
        // Abort alert
        .alert(#localize("abort_verification"), isPresented: $viewModel.showAbortVerificationAlert) {
            Button(role: .destructive) {
                viewModel.abortVerification()
            }
            label: {
                Text(#localize("abort_verification"))
            }
            
            Button(role: .cancel) {
                // No-op
            } label: {
                Text(#localize("cancel"))
            }
        }
       
        // Error alert
        .alert(viewModel.errorText, isPresented: $viewModel.showError) {
            Button(role: .cancel) {
                // No-op
            } label: {
                Text(#localize("ok"))
            }
        }
    }
}
