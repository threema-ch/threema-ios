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

public enum DeleteRevokeType {
    case delete, revoke
}

struct DeleteRevokeSummaryView: View {
    var type: DeleteRevokeType
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(BundleUtil.localizedString(forKey: "my_profile_delete_identity_summary_view_removed_title"))
                    .bold()
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        BundleUtil
                            .localizedString(forKey: "my_profile_delete_identity_summary_view_removed_success")
                    )
                    .font(.headline)
                    
                    BulletText(
                        string: BundleUtil.localizedString(forKey: "my_profile_delete_bullet_id"),
                        showIcon: true
                    )
                    BulletText(
                        string: BundleUtil.localizedString(forKey: "my_profile_delete_bullet_chats"),
                        showIcon: true
                    )
                    BulletText(
                        string: BundleUtil.localizedString(forKey: "my_profile_delete_bullet_picture"),
                        showIcon: true
                    )
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                
                if type == .revoke {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(
                            BundleUtil
                                .localizedString(
                                    forKey: "my_profile_delete_identity_summary_view_removed_server_success"
                                )
                        )
                        .font(.headline)
                        
                        BulletText(
                            string: BundleUtil.localizedString(forKey: "my_profile_delete_bullet_safe"),
                            showIcon: true
                        )
                        BulletText(
                            string: BundleUtil.localizedString(forKey: "my_profile_delete_bullet_linked"),
                            showIcon: true
                        )
                    }
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Label {
                            Text(
                                BundleUtil
                                    .localizedString(
                                        forKey: "my_profile_delete_identity_summary_view_removed_threema_id"
                                    )
                            )
                            .bold()
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(UIColor.primary.color)
                        }
                        .labelStyle(TrailingLabelStyle())
                    }
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                }
                     
                switch type {
                case .delete:
                    Text(BundleUtil.localizedString(forKey: "my_profile_delete_identity_summary_view_restart"))
                case .revoke:
                    Text(BundleUtil.localizedString(forKey: "my_profile_delete_identity_summary_view_restart_new"))
                }
                                
                Button {
                    exit(1)
                } label: {
                    Text(BundleUtil.localizedString(forKey: "my_profile_delete_identity_summary_view_close"))
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.white)
            .cornerRadius(16)
            .padding()
        }
        .frame(maxHeight: .infinity)
        .multilineTextAlignment(.center)
        
        .background(Color(uiColor: Colors.backgroundWizard))

        .navigationBarBackButtonHidden(true)
        .dynamicTypeSize(.small ... .accessibility2)
        .colorScheme(.light)
        .highPriorityGesture(DragGesture())
    }
}

struct DeleteRevokeSummaryView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DeleteRevokeSummaryView(type: .delete)

            DeleteRevokeSummaryView(type: .revoke)
        }
        .tint(UIColor.primary.color)
    }
}
