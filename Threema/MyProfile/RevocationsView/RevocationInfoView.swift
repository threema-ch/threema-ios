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

struct RevokeIdentityInfoView: View {
    @Environment(\.dismiss) var dismiss

    @State var revokeSuccessful = false
    @State var isDeleting = false
    @State var textIsSameAsID = false
    @State var enteredText = ""
    
    let identity = MyIdentityStore.shared().identity!
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(BundleUtil.localizedString(forKey: "my_profile_revoke_identity_view_title"))
                    .bold()
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(BundleUtil.localizedString(forKey: "my_profile_revoke_info_delete"))
                        .bold()
                    BulletText(string: BundleUtil.localizedString(forKey: "my_profile_delete_bullet_id"))
                    BulletText(string: BundleUtil.localizedString(forKey: "my_profile_delete_bullet_chats"))
                    BulletText(string: BundleUtil.localizedString(forKey: "my_profile_delete_bullet_picture"))
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(BundleUtil.localizedString(forKey: "my_profile_revoke_info_sever"))
                        .bold()
                    BulletText(string: BundleUtil.localizedString(forKey: "my_profile_delete_bullet_id"))
                    BulletText(string: BundleUtil.localizedString(forKey: "my_profile_delete_bullet_safe"))
                    BulletText(string: BundleUtil.localizedString(forKey: "my_profile_delete_bullet_linked"))
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                
                Label {
                    if textIsSameAsID {
                        Text(BundleUtil.localizedString(forKey: "my_profile_delete_info_revoke"))
                            .foregroundColor(Colors.red.color)
                            .bold()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    else {
                        Text(BundleUtil.localizedString(forKey: "my_profile_delete_info_revoke"))
                            .foregroundColor(Colors.red.color)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Colors.orange.color)
                }
                    
                VStack(alignment: .leading, spacing: 8) {
                    Text(String.localizedStringWithFormat(
                        BundleUtil.localizedString(forKey: "my_profile_revoke_identity_view_enter_id"),
                        identity
                    ))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                                            
                    TextField(
                        BundleUtil.localizedString(forKey: "my_profile_revoke_identity_view_placeholder"),
                        text: $enteredText
                    )
                    .textFieldStyle(.roundedBorder)
                    .textCase(.uppercase)
                    .textInputAutocapitalization(.characters)
                    .padding(.horizontal)
                    .padding(.horizontal)
                    .onChange(of: enteredText) { newValue in
                        if newValue == identity {
                            textIsSameAsID = true
                        }
                        else {
                            textIsSameAsID = false
                        }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                                
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
                    .disabled(isDeleting)
                    .fixedSize()
                    
                    Spacer()
                    
                    Button(role: .destructive) {
                        revokePressed()
                    } label: {
                        Text(BundleUtil.localizedString(forKey: "my_profile_revoke_identity_view_button_revoke"))
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!textIsSameAsID)
                    .disabled(isDeleting)
                    .fixedSize()
                        
                    NavigationLink(
                        isActive: $revokeSuccessful,
                        destination: { DeleteRevokeSummaryView(type: .revoke) },
                        label: {
                            EmptyView()
                        }
                    )
                }
                .fixedSize(horizontal: false, vertical: false)
                .padding(.vertical)
            }
            .padding()
            .background(.white)
            .cornerRadius(16)
            .padding()
        }
        .frame(maxHeight: .infinity)
        .multilineTextAlignment(.center)
        .navigationBarHidden(true)
        
        .background(Color(uiColor: Colors.backgroundWizard))
        .navigationBarBackButtonHidden(true)
        .dynamicTypeSize(.small ... .xxLarge)
        .colorScheme(.light)
    }
    
    // MARK: - Private Functions
    
    private func revokePressed() {
        isDeleting = true
        Task { @MainActor in
            do {
                try await DeleteRevokeIdentityManager.revokeIdentity()
                DeleteRevokeIdentityManager.deleteBackups()
                await DeleteRevokeIdentityManager.deleteLocalData()
                revokeSuccessful = true
            }
            catch {
                NotificationPresenterWrapper.shared.present(type: .revocationFailed)
                isDeleting = false
                enteredText = ""
            }
        }
    }
}

struct RevokeIdentityInfoView_Previews: PreviewProvider {
    static var previews: some View {
        RevokeIdentityInfoView()
            .tint(UIColor.primary.color)
    }
}
