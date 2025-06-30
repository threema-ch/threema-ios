//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import SwiftUI
import ThreemaMacros

struct DeleteRevokeOverviewView: View {
    @Environment(\.dismiss) var dismiss
    
    @Binding var tabSelection: Int
    
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
                        Button(role: .destructive, action: {
                            showConfirmationAlert = true
                        }, label: {
                            Text(#localize("my_profile_delete_info_button"))
                                .frame(maxWidth: .infinity)
                        })
                        .buttonStyle(.bordered)
                        
                        Button {
                            dismiss()
                        } label: {
                            Text(#localize("cancel"))
                                .frame(maxWidth: .infinity)
                                .foregroundColor(Colors.textProminentButtonWizard.color)
                        }
                        .buttonStyle(.borderedProminent)
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
    DeleteRevokeOverviewView(tabSelection: .constant(1))
        .background(.black)
}
