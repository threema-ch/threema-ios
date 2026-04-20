import SwiftUI
import ThreemaFramework
import ThreemaMacros

struct LinkEmailLinkedView: View {
    @ObservedObject var viewModel: LinkEmailViewModel
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text(#localize("profile_linked_email"))
                    Spacer()
                    Text(viewModel.email)
                }
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
                        title: #localize("profile_code_email_unlink"),
                        role: .destructive,
                        style: .bordered,
                        size: .small
                    ) {
                        viewModel.unlinkEmail()
                    }
                    .padding()
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
