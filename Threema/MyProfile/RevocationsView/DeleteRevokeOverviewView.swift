import SwiftUI
import ThreemaFramework
import ThreemaMacros

struct DeleteRevokeOverviewView: View {
    @Binding var tabSelection: Int
    var onDismiss: () -> Void
    
    @State private var showConfirmationAlert = false
    
    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack {
                    Text(#localize("my_profile_delete_info_title"))
                        .bold()
                        .font(.title2)
                    
                    GroupBox {
                        Text(String.localizedStringWithFormat(
                            #localize("my_profile_delete_info_keep"),
                            TargetManager.localizedAppName
                        ))
                        .padding(.top, 4)
                    } label: {
                        Label(
                            String.localizedStringWithFormat(
                                #localize("my_profile_delete_info_delete"),
                                TargetManager.appName
                            ),
                            systemImage: "trash.circle.fill"
                        )
                    }
                    
                    .groupBoxStyle(.info)
                    
                    HStack {
                        Text(String.localizedStringWithFormat(
                            #localize("my_profile_delete_info_revoke_info"),
                            TargetManager.localizedAppName
                        ))
                        .italic() +
                        Text(.init(String.localizedStringWithFormat(
                            #localize("my_profile_delete_info_revoke_info_link"),
                            TargetManager.localizedAppName
                        )))
                        .underline()
                        .italic()
                        Spacer()
                    }
                    .font(.footnote)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    VStack(spacing: 12) {
                        ThreemaButton(
                            title: #localize("my_profile_delete_info_button"),
                            role: .destructive,
                            style: .bordered,
                            size: .fullWidth
                        ) {
                            showConfirmationAlert = true
                        }
                        
                        ThreemaButton(
                            title: #localize("cancel"),
                            style: .borderedProminent,
                            size: .fullWidth
                        ) {
                            onDismiss()
                        }
                    }
                    .padding(.horizontal)
                }
                .environment(\.openURL, OpenURLAction(handler: handleURL))
                .frame(maxHeight: .infinity)
                .frame(minHeight: proxy.size.height)
            }
            .alert(
                String.localizedStringWithFormat(
                    #localize("my_profile_delete_info_alert_title"),
                    TargetManager.localizedAppName
                ),
                isPresented: $showConfirmationAlert,
                actions: {
                    Button(
                        #localize("my_profile_delete_info_alert_confirm"),
                        role: .destructive
                    ) {
                        Task { @MainActor in
                            await DeleteRevokeIdentityManager.deleteLocalData()
                            
                            tabSelection = 2
                        }
                    }
                    Button(#localize("cancel"), role: .cancel) {
                        // Do nothing
                    }
                }
            )
        }
    }
    
    private func handleURL(_ url: URL) -> OpenURLAction.Result {
        tabSelection = 1
        return .discarded
    }
}

#Preview {
    DeleteRevokeOverviewView(tabSelection: .constant(1)) { }
        .preferredColorScheme(.dark)
}
