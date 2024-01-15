//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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

struct DeleteRevokeInfoView: View {
    @Environment(\.dismiss) var dismiss

    @State var revokeToggleIsOn = false
    @State var showRevoke = false
    @State var showDelete = false
    @State var deleteConfirmed = false
        
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Text(BundleUtil.localizedString(forKey: "my_profile_delete_info_title"))
                        .bold()
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(BundleUtil.localizedString(forKey: "my_profile_delete_info_delete"))
                            .font(.headline)
                        BulletText(string: BundleUtil.localizedString(forKey: "my_profile_delete_bullet_id"))
                        BulletText(string: BundleUtil.localizedString(forKey: "my_profile_delete_bullet_chats"))
                        BulletText(string: BundleUtil.localizedString(forKey: "my_profile_delete_bullet_picture"))
                    }
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    
                    if revokeToggleIsOn {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(BundleUtil.localizedString(forKey: "my_profile_delete_info_delete_server"))
                                .font(.headline)
                            BulletText(string: BundleUtil.localizedString(forKey: "my_profile_delete_bullet_id"))
                            BulletText(string: BundleUtil.localizedString(forKey: "my_profile_delete_bullet_safe"))
                            BulletText(string: BundleUtil.localizedString(forKey: "my_profile_delete_bullet_linked"))
                        }
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        
                        Label {
                            Text(BundleUtil.localizedString(forKey: "my_profile_delete_info_revoke"))
                                .font(.headline)
                                .foregroundColor(Colors.red.color)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Colors.orange.color)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(BundleUtil.localizedString(forKey: "my_profile_delete_info_keep"))
                        }
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                                        
                    VStack(alignment: .leading, spacing: 2) {
                        Toggle(
                            BundleUtil.localizedString(forKey: "my_profile_delete_info_toggle"),
                            isOn: $revokeToggleIsOn
                        )
                        .font(.headline)
                    }
                    .padding(.vertical, 20.0)
                                        
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Text(BundleUtil.localizedString(forKey: "cancel"))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .fixedSize()
                        
                        Spacer()
                        
                        Button(role: .destructive, action: {
                            if revokeToggleIsOn {
                                showRevoke = true
                            }
                            else {
                                showDelete = true
                            }
                        }, label: {
                            Label {
                                Text(BundleUtil.localizedString(forKey: "my_profile_delete_info_button"))
                            } icon: {
                                Image(systemName: "chevron.forward")
                            }
                            .labelStyle(TrailingLabelStyle())
                            .fixedSize(horizontal: false, vertical: true)
                        })
                        .buttonStyle(.bordered)
                    }
                    .fixedSize(horizontal: false, vertical: false)
                    .padding(.vertical)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.white)
                .cornerRadius(16)
                .padding()
                
                NavigationLink(
                    isActive: $showRevoke,
                    destination: { RevokeIdentityInfoView() },
                    label: {
                        EmptyView()
                    }
                )
                                
                NavigationLink(
                    isActive: $deleteConfirmed,
                    destination: { DeleteRevokeSummaryView(type: .delete) },
                    label: {
                        EmptyView()
                    }
                )
            }
            .frame(maxHeight: .infinity)
            .multilineTextAlignment(.center)
            .navigationBarHidden(true)
            .background(Color(uiColor: Colors.backgroundWizard))
            .dynamicTypeSize(.small ... .xxxLarge)
            .colorScheme(.light)
            .navigationBarBackButtonHidden(true)
            .animation(.linear(duration: 0.1), value: revokeToggleIsOn)
        }
        
        .alert(
            BundleUtil.localizedString(forKey: "my_profile_delete_info_alert_title"),
            isPresented: $showDelete,
            actions: {
                Button(
                    BundleUtil.localizedString(forKey: "my_profile_delete_info_alert_confirm"),
                    role: .destructive
                ) {
                    Task { @MainActor in
                        await DeleteRevokeIdentityManager.deleteLocalData()
                        deleteConfirmed = true
                    }
                }
                Button(BundleUtil.localizedString(forKey: "cancel"), role: .cancel) {
                    // do nothing
                }
            }
        )
    }
}

struct DeleteRevokeInfoView_Previews: PreviewProvider {
    static var previews: some View {
        DeleteRevokeInfoView()
    }
}
