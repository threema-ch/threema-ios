import SwiftUI
import ThreemaFramework
import ThreemaMacros

struct LinkPhoneNumberUnlinkedView: View {
    @ObservedObject var viewModel: LinkPhoneNumberViewModel
    @State private var phoneNumber = ""

    var body: some View {
        List {
            Section {
                TextField(viewModel.phoneNumberPlaceholder, text: $phoneNumber)
                    .keyboardType(.phonePad)
            }
            header: {
                Text(#localize("profile_code_phone_number"))
            }
            footer: {
                VStack(spacing: 20) {
                    if TargetManager.isOnPrem, let serverName = viewModel.serverName {
                        Text(String.localizedStringWithFormat(
                            #localize("myprofile_link_phone_onprem_footer"),
                            serverName,
                            TargetManager.appName
                        ))
                    }
                    else {
                        Text(String.localizedStringWithFormat(
                            #localize("myprofile_link_phone_footer"),
                            TargetManager.appName
                        ))
                    }

                    ThreemaButton(
                        title: #localize("profile_code_verify"),
                        style: .borderedProminent,
                        size: .small
                    ) {
                        viewModel.verifyPhoneNumber(phoneNumber)
                    }
                    .disabled(phoneNumber.isEmpty)
                }
            }
        }
        .alert(#localize("bad_phone_number_format_title"), isPresented: $viewModel.showInvalidPhoneNumberAlert) {
            Button(role: .cancel) {
                // No-op
            } label: {
                Text(#localize("ok"))
            }
        } message: {
            Text(#localize("bad_phone_number_format_message"))
        }
        .alert(#localize("confirm_phone_number_title"), isPresented: $viewModel.showConfirmationAlert) {
            Button {
                viewModel.linkPhoneNumber()
            } label: {
                Text(#localize("profile_code_verify"))
            }
            
            Button(role: .cancel) {
                // No-op
            } label: {
                Text(#localize("cancel"))
            }
        } message: {
            Text(String.localizedStringWithFormat(#localize("confirm_phone_number_x"), viewModel.formattedNumber))
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
