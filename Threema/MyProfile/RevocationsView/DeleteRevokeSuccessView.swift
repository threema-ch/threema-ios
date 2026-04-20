import SwiftUI
import ThreemaFramework
import ThreemaMacros

struct DeleteRevokeSuccessView: View {
    
    @Binding var successViewType: SuccessViewType

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack {
                    Text(#localize("my_profile_delete_identity_summary_view_removed_title"))
                        .bold()
                        .font(.title2)
                    
                    if successViewType == .delete {
                        GroupBox {
                            VStack(alignment: .leading) {
                                Label {
                                    Text(String.localizedStringWithFormat(
                                        #localize("my_profile_delete_bullet_id"),
                                        TargetManager.localizedAppName
                                    ))
                                } icon: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                                Label {
                                    Text(#localize("my_profile_delete_bullet_chats"))
                                } icon: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                                Label {
                                    Text(#localize("my_profile_delete_bullet_picture"))
                                } icon: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.top, 1)
                            .padding(.leading, 24.0)
                            .padding(.bottom)
                            
                            Text(#localize("my_profile_delete_identity_summary_view_restart"))
                        } label: {
                            Label(
                                String.localizedStringWithFormat(
                                    #localize("my_profile_delete_identity_summary_view_removed_success"),
                                    TargetManager.appName
                                ),
                                systemImage: "checkmark.shield.fill"
                            )
                        }
                        .groupBoxStyle(.info)
                    }
                    else {
                        
                        GroupBox {
                            VStack(alignment: .leading) {
                                Label {
                                    Text(String.localizedStringWithFormat(
                                        #localize("my_profile_delete_bullet_id"),
                                        TargetManager.localizedAppName
                                    ))
                                } icon: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                                Label {
                                    Text(String.localizedStringWithFormat(
                                        #localize("my_profile_delete_bullet_safe"),
                                        TargetManager.localizedAppName
                                    ))
                                } icon: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                                Label {
                                    Text(#localize("my_profile_delete_bullet_linked"))
                                } icon: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.top, 1.0)
                            .padding(.leading, 24.0)
                            
                            Label {
                                Text(String.localizedStringWithFormat(
                                    #localize("my_profile_delete_identity_summary_view_removed_threema_id"),
                                    TargetManager.localizedAppName
                                ))
                            } icon: {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.white, .red)
                            }
                            .padding(.vertical)
                            
                            Text(String.localizedStringWithFormat(
                                #localize("my_profile_delete_identity_summary_view_restart_new"),
                                TargetManager.localizedAppName
                            ))

                        } label: {
                            Label(
                                String.localizedStringWithFormat(
                                    #localize("my_profile_delete_identity_summary_view_removed_server_success"),
                                    TargetManager.appName,
                                    TargetManager.appName
                                ),
                                systemImage: "checkmark.shield.fill"
                            )
                        }
                        .groupBoxStyle(.info)
                    }
                    
                    Spacer()
                    
                    ThreemaButton(
                        title: #localize("my_profile_delete_identity_summary_view_close"),
                        style: .borderedProminent,
                        size: .fullWidth
                    ) {
                        exit(1)
                    }
                }
                .padding(.horizontal)
                .frame(maxHeight: .infinity)
                .frame(minHeight: proxy.size.height)
            }
        }
    }
}

#Preview {
    DeleteRevokeSuccessView(successViewType: .constant(.revoke))
        .preferredColorScheme(.dark)
}
