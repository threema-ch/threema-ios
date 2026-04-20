import SwiftUI
import ThreemaFramework
import ThreemaMacros

struct LinkPhoneNumberLinkedView: View {
    @ObservedObject var viewModel: LinkPhoneNumberViewModel
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text(#localize("profile_linked_phone"))
                    Spacer()
                    Text(viewModel.formattedNumber)
                }
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
                        title: #localize("profile_code_number_unlink"),
                        role: .destructive,
                        style: .bordered,
                        size: .small
                    ) {
                        viewModel.unlinkPhoneNumber()
                    }
                }
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
