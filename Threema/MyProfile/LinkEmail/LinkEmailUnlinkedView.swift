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

struct LinkEmailUnlinkedView: View {
    @ObservedObject var viewModel: LinkEmailViewModel
    @State private var email = ""
    
    var body: some View {
        List {
            Section {
                TextField(#localize("link_email_textfield_placeholder"), text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            header: {
                Text(#localize("link_email_textfield_title"))
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
                    Button {
                        viewModel.verifyEmail(email)
                    } label: {
                        Text(#localize("profile_code_verify"))
                            .font(.headline)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .clipShape(Capsule())
                    .disabled(email.isEmpty)
                }
            }
        }
        // Alerts
        .alert(#localize("invalid_email_address_title"), isPresented: $viewModel.showInvalidEmailAlert) {
            Button(role: .cancel) {
                // No-op
            } label: {
                Text(#localize("ok"))
            }
        } message: {
            Text(#localize("invalid_email_address_message"))
        }
        .alert(#localize("confirm_email_title"), isPresented: $viewModel.showConfirmationAlert) {
            Button {
                viewModel.linkEmail()
            } label: {
                Text(#localize("profile_code_verify"))
            }
            
            Button(role: .cancel) {
                // No-op
            } label: {
                Text(#localize("cancel"))
            }
        } message: {
            Text(String.localizedStringWithFormat(#localize("confirm_email_message"), viewModel.email))
        }
        .alert(viewModel.errorText, isPresented: $viewModel.showError) {
            Button(role: .cancel) {
                // No-op
            } label: {
                Text(#localize("ok"))
            }
        }
    }
}
