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
                        GroupBox(
                            label: Label(
                                #localize("my_profile_delete_identity_summary_view_removed_success"),
                                systemImage: "checkmark.shield.fill"
                            ),
                            content: {
                                VStack(alignment: .leading) {
                                    Label {
                                        Text(#localize("my_profile_delete_bullet_id"))
                                    } icon: {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Colors.green.color)
                                    }
                                    Label {
                                        Text(#localize("my_profile_delete_bullet_chats"))
                                    } icon: {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Colors.green.color)
                                    }
                                    Label {
                                        Text(#localize("my_profile_delete_bullet_picture"))
                                    } icon: {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Colors.green.color)
                                    }
                                }
                                .padding(.top, 1)
                                .padding(.leading, 24.0)
                                .padding(.bottom)
                                
                                Text(#localize("my_profile_delete_identity_summary_view_restart"))
                            }
                        )
                        .groupBoxStyle(.info)
                    }
                    else {
                        GroupBox(
                            label: Label(
                                #localize("my_profile_delete_identity_summary_view_removed_server_success"),
                                systemImage: "checkmark.shield.fill"
                            ),
                            content: {
                                VStack(alignment: .leading) {
                                    Label {
                                        Text(#localize("my_profile_delete_bullet_id"))
                                    } icon: {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Colors.green.color)
                                    }
                                    Label {
                                        Text(#localize("my_profile_delete_bullet_safe"))
                                    } icon: {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Colors.green.color)
                                    }
                                    Label {
                                        Text(#localize("my_profile_delete_bullet_linked"))
                                    } icon: {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Colors.green.color)
                                    }
                                }
                                .padding(.top, 1.0)
                                .padding(.leading, 24.0)
                                
                                Label {
                                    Text(#localize("my_profile_delete_identity_summary_view_removed_threema_id"))
                                } icon: {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(Colors.white.color, Colors.red.color)
                                }
                                .padding(.vertical)
                                
                                Text(#localize("my_profile_delete_identity_summary_view_restart_new"))
                            }
                        )
                        
                        .groupBoxStyle(.info)
                    }
                    
                    Spacer()
                    
                    Button {
                        exit(1)
                    } label: {
                        Text(#localize("my_profile_delete_identity_summary_view_close"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                }
                .frame(maxHeight: .infinity)
                .frame(minHeight: proxy.size.height)
            }
        }
    }
}

#Preview {
    DeleteRevokeSuccessView(successViewType: .constant(.revoke))
        .background(
            Image("WizardBg")
                .resizable()
                .scaledToFill()
                .accessibilityHidden(true)
                .edgesIgnoringSafeArea(.all)
        )
}
