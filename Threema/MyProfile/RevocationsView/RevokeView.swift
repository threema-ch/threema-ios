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

struct RevokeView: View {
    private let identity = MyIdentityStore.shared().identity!
    
    @Binding var tabSelection: Int
    @Binding var successViewType: SuccessViewType
    
    @State private var isDeleting = false
    @State private var textIsSameAsID = false
    @State private var enteredText = ""
    
    // Workaround: TextField has the wrong color
    @State private var textFieldColor: Color = .black
    
    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack {
                    Text(#localize("my_profile_revoke_identity_view_title"))
                        .bold()
                        .font(.title2)
                    
                    GroupBox(
                        label: Label(
                            #localize("my_profile_revoke_info_delete"),
                            systemImage: "trash.circle.fill"
                        ),
                        content: {
                            VStack(alignment: .leading) {
                                BulletText(string: #localize("my_profile_delete_bullet_id"))
                                BulletText(string: #localize("my_profile_delete_bullet_safe"))
                                BulletText(string: #localize("my_profile_delete_bullet_linked"))
                            }
                            .padding(.leading, 24.0)
                            .padding(.top, 1)
                            
                            VStack(alignment: .leading) {
                                Text(
                                    String
                                        .localizedStringWithFormat(
                                            #localize("my_profile_revoke_identity_view_enter_id"),
                                            identity
                                        )
                                )
                                
                                TextField(#localize("my_profile_revoke_identity_view_placeholder"), text: $enteredText)
                                    .foregroundStyle(textFieldColor)
                                    .textFieldStyle(.roundedBorder)
                                    .textCase(.uppercase)
                                    .textInputAutocapitalization(.characters)
                                    .onChange(of: enteredText) { newValue in
                                        // Workaround: TextField has the wrong color
                                        textFieldColor = .white
                                        textIsSameAsID = newValue == identity
                                    }
                            }
                            .padding(.top)
                        }
                    )
                    .groupBoxStyle(.info)
                    
                    GroupBox(label: EmptyView(), content: {
                        Label {
                            Text(#localize("my_profile_delete_info_revoke"))
                                .foregroundColor(textIsSameAsID ? Colors.red.color : Colors.white.color)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(
                                    Colors.white.color,
                                    textIsSameAsID ? Colors.red.color : Colors.orange.color
                                )
                        }
                    })
                    .groupBoxStyle(.info)
                    
                    Spacer()
                    
                    VStack(spacing: 12) {
                        Button(role: .destructive, action: {
                            revokePressed()
                        }, label: {
                            Text(#localize("my_profile_revoke_identity_view_button_revoke"))
                                .frame(maxWidth: .infinity)
                        })
                        .disabled(isDeleting)
                        .buttonStyle(.bordered)
                        .disabled(!textIsSameAsID)
                        
                        Button {
                            tabSelection = 0
                        } label: {
                            Text(#localize("back"))
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(isDeleting)
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.horizontal)
                }
                .frame(maxHeight: .infinity)
                .frame(minHeight: proxy.size.height)
            }
        }
        .opacity(tabSelection != 2 || successViewType == .revoke ? 1.0 : 0.0)
        .onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }
    }
    
    private func revokePressed() {
        isDeleting = true
        Task { @MainActor in
            do {
                try await DeleteRevokeIdentityManager.revokeIdentity()
                DeleteRevokeIdentityManager.deleteBackups()
                await DeleteRevokeIdentityManager.deleteLocalData()
                successViewType = .revoke
                tabSelection = 2
            }
            catch {
                NotificationPresenterWrapper.shared.present(type: .revocationFailed)
                isDeleting = false
                enteredText = ""
            }
        }
    }
}

#Preview {
    RevokeView(tabSelection: .constant(1), successViewType: .constant(.revoke))
        .background(
            Image("WizardBg")
                .resizable()
                .scaledToFill()
                .accessibilityHidden(true)
                .edgesIgnoringSafeArea(.all)
        )
}
