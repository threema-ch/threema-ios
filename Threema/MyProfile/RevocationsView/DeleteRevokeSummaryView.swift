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
    
    var title: String {
        switch self {
        case .delete:
            return BundleUtil.localizedString(forKey: "my_profile_delete_identity_summary_view_delete_title")
        case .revoke:
            return BundleUtil.localizedString(forKey: "my_profile_delete_identity_summary_view_revoke_title")
        }
    }
}

struct DeleteRevokeSummaryView: View {
    var type: DeleteRevokeType
    
    var body: some View {
        VStack {
            VStack(spacing: 16) {
                Text(type.title)
                    .bold()
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    if type == .revoke {
                        Text(
                            BundleUtil
                                .localizedString(forKey: "my_profile_delete_identity_summary_view_revoke_success")
                        )
                        .font(.headline)
                    }
                    else {
                        Text(
                            BundleUtil
                                .localizedString(forKey: "my_profile_delete_identity_summary_view_delete_success")
                        )
                        .font(.headline)
                    }
                    
                    BulletText(
                        string: BundleUtil.localizedString(forKey: "my_profile_delete_bullet_id"),
                        showIcon: true
                    )
                    BulletText(
                        string: BundleUtil.localizedString(forKey: "my_profile_delete_bullet_chats"),
                        showIcon: true
                    )
                    BulletText(
                        string: BundleUtil.localizedString(forKey: "my_profile_delete_bullet_linked"),
                        showIcon: true
                    )

                    if type == .revoke {
                        BulletText(
                            string: BundleUtil.localizedString(forKey: "my_profile_delete_bullet_safe"),
                            showIcon: true
                        )
                        BulletText(
                            string: BundleUtil.localizedString(forKey: "my_profile_delete_bullet_picture"),
                            showIcon: true
                        )
                    }
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                if type == .delete {
                    Text(BundleUtil.localizedString(forKey: "my_profile_delete_identity_summary_view_restart"))
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
