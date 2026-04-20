import SwiftUI
import ThreemaFramework
import ThreemaMacros

struct LinkEmailUnlinkedView: View {
    @ObservedObject var viewModel: LinkEmailViewModel
    @State private var email = ""
    
    var body: some View {
        List {
            Section {
                TextField(#localize("link_email_textfield_placeholder"), text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            header: {
                Text(#localize("link_email_textfield_title"))
            }
            footer: {
                VStack(spacing: 20) {
                    if TargetManager.isOnPrem, let serverName = viewModel.serverName {
                        Text(String.localizedStringWithFormat(
                            #localize("myprofile_link_email_onprem_footer"),
                            serverName,
                            TargetManager.appName
                        ))
                    }
                    else {
                        Text(String.localizedStringWithFormat(
                            #localize("myprofile_link_email_footer"),
                            TargetManager.appName
                        ))
                    }
                    ThreemaButton(
                        title: #localize("profile_code_verify"),
                        style: .borderedProminent,
                        size: .small
                    ) {
                        viewModel.verifyEmail(email)
                    }
                    .disabled(email.isEmpty)
                }
            }
        }
        // Alerts
        .alert(#localize("invalid_email_address_title"), isPresented: $viewModel.showInvalidEmailAlert) {
            Button(role: .cancel) {
                // No-op
            } label: {
                Text(#localize("ok"))
            }
        } message: {
            Text(#localize("invalid_email_address_message"))
        }
        .alert(#localize("confirm_email_title"), isPresented: $viewModel.showConfirmationAlert) {
            Button {
                viewModel.linkEmail()
            } label: {
                Text(#localize("profile_code_verify"))
            }
            
            Button(role: .cancel) {
                // No-op
            } label: {
                Text(#localize("cancel"))
            }
        } message: {
            Text(String.localizedStringWithFormat(#localize("confirm_email_message"), viewModel.email))
        }
        .alert(viewModel.errorText, isPresented: $viewModel.showError) {
            Button(role: .cancel) {
                // No-op
            } label: {
                Text(#localize("ok"))
            }
        }
    }
}
