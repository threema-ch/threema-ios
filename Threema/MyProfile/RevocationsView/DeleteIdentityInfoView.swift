//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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

struct DeleteIdentityInfoView: View {
    
    @Environment(\.dismiss) var dismiss

    @State var deletePressed = false
    @State var deleteConfirmed = false
    
    var body: some View {
        VStack {
            VStack(spacing: 16) {
                Text(BundleUtil.localizedString(forKey: "my_profile_delete_identity_title"))
                    .bold()
                    .font(.title2)
                    
                VStack(alignment: .leading, spacing: 4) {
                    Text(BundleUtil.localizedString(forKey: "my_profile_delete_identity_keep"))
                        .font(.headline)
                    BulletText(string: BundleUtil.localizedString(forKey: "my_profile_delete_bullet_id"))
                    BulletText(string: BundleUtil.localizedString(forKey: "my_profile_delete_bullet_safe"))
                    BulletText(string: BundleUtil.localizedString(forKey: "my_profile_delete_bullet_linked"))
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                    
                VStack(alignment: .leading, spacing: 4) {
                    Text(BundleUtil.localizedString(forKey: "my_profile_delete_identity_remove"))
                        .font(.headline)
                    BulletText(string: BundleUtil.localizedString(forKey: "my_profile_delete_bullet_chats"))
                    BulletText(string: BundleUtil.localizedString(forKey: "my_profile_delete_bullet_id"))
                    BulletText(string: BundleUtil.localizedString(forKey: "my_profile_delete_bullet_picture"))
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                    
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Label {
                            Text(BundleUtil.localizedString(forKey: "back"))
                        } icon: {
                            Image(systemName: "chevron.backward")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .fixedSize()
                    
                    Spacer()
                    
                    Button(role: .destructive, action: {
                        deletePressed = true

                    }, label: {
                        Text(BundleUtil.localizedString(forKey: "my_profile_delete_identity_delete"))
                    })
                    .buttonStyle(.bordered)
                    .fixedSize()
                                                
                    NavigationLink(
                        isActive: $deleteConfirmed,
                        destination: { DeleteRevokeSummaryView(type: .delete) },
                        label: {
                            EmptyView()
                        }
                    )
                }
                .fixedSize(horizontal: false, vertical: false)
                .padding(.vertical)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.white)
            .cornerRadius(16)
            .padding()
        }
        .frame(maxHeight: .infinity)
        .multilineTextAlignment(.center)
        
        .alert(
            BundleUtil.localizedString(forKey: "my_profile_delete_identity_view_alert_title"),
            isPresented: $deletePressed,
            actions: {
                Button(
                    BundleUtil.localizedString(forKey: "my_profile_delete_identity_view_alert_confirm"),
                    role: .destructive
                ) {
                    DeleteRevokeIdentityManager.deleteLocalData()
                    deleteConfirmed = true
                }
                Button(BundleUtil.localizedString(forKey: "cancel"), role: .cancel) {
                    // do nothing
                }
            }
        )
        
        .background(Color(uiColor: Colors.backgroundWizard))
        .navigationBarBackButtonHidden(true)
        .dynamicTypeSize(.small ... .xxxLarge)
        .colorScheme(.light)
    }
}

struct DeleteIdentityInfoView_Previews: PreviewProvider {
    static var previews: some View {
        DeleteIdentityInfoView()
            .tint(UIColor.primary.color)
    }
}
