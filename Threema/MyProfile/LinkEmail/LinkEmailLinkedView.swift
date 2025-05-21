//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

struct LinkEmailLinkedView: View {
    @ObservedObject var viewModel: LinkEmailViewModel
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text(#localize("profile_linked_email"))
                    Spacer()
                    Text(viewModel.email)
                }
            }
            footer: {
                VStack(spacing: 20) {
                    if TargetManager.isOnPrem, let serverName = viewModel.serverName {
                        Text(String.localizedStringWithFormat(
                            #localize("myprofile_link_email_onprem_footer"),
                            serverName,
                            TargetManager.appName
                        ))
                    }
                    else {
                        Text(String.localizedStringWithFormat(
                            #localize("myprofile_link_email_footer"),
                            TargetManager.appName
                        ))
                    }
                    
                    Button(role: .destructive) {
                        viewModel.unlinkEmail()
                    } label: {
                        Text(#localize("profile_code_email_unlink"))
                            .font(.headline)
                    }
                    .controlSize(.large)
                    .buttonStyle(.bordered)
                    .clipShape(Capsule())
                    .padding()
                }
            }
        }
        // Error alert
        .alert(viewModel.errorText, isPresented: $viewModel.showError) {
            Button(role: .cancel) {
                // No-op
            } label: {
                Text(#localize("ok"))
            }
        }
    }
}
