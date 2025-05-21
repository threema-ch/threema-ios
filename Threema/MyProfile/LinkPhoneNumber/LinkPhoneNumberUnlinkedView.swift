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

struct LinkPhoneNumberUnlinkedView: View {
    @ObservedObject var viewModel: LinkPhoneNumberViewModel
    @State private var phoneNumber = ""

    var body: some View {
        List {
            Section {
                TextField(viewModel.phoneNumberPlaceholder, text: $phoneNumber)
                    .keyboardType(.phonePad)
            }
            header: {
                Text(#localize("profile_code_phone_number"))
            }
            footer: {
                VStack(spacing: 20) {
                    if TargetManager.isOnPrem, let serverName = viewModel.serverName {
                        Text(String.localizedStringWithFormat(
                            #localize("myprofile_link_phone_onprem_footer"),
                            serverName,
                            TargetManager.appName
                        ))
                    }
                    else {
                        Text(String.localizedStringWithFormat(
                            #localize("myprofile_link_phone_footer"),
                            TargetManager.appName
                        ))
                    }
                    Button {
                        viewModel.verifyPhoneNumber(phoneNumber)
                    } label: {
                        Text(#localize("profile_code_verify"))
                            .font(.headline)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .clipShape(Capsule())
                    .disabled(phoneNumber.isEmpty)
                }
            }
        }
        .alert(#localize("bad_phone_number_format_title"), isPresented: $viewModel.showInvalidPhoneNumberAlert) {
            Button(role: .cancel) {
                // No-op
            } label: {
                Text(#localize("ok"))
            }
        } message: {
            Text(#localize("bad_phone_number_format_message"))
        }
        .alert(#localize("confirm_phone_number_title"), isPresented: $viewModel.showConfirmationAlert) {
            Button {
                viewModel.linkPhoneNumber()
            } label: {
                Text(#localize("profile_code_verify"))
            }
            
            Button(role: .cancel) {
                // No-op
            } label: {
                Text(#localize("cancel"))
            }
        } message: {
            Text(String.localizedStringWithFormat(#localize("confirm_phone_number_x"), viewModel.formattedNumber))
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
