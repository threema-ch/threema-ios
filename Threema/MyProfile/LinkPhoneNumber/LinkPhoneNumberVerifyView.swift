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

struct LinkPhoneNumberVerifyView: View {
    @ObservedObject var viewModel: LinkPhoneNumberViewModel
    @State private var verificationCode = ""
    
    var body: some View {
        List {
            Section {
                TextField(#localize("profile_code_code"), text: $verificationCode)
                    .textContentType(.oneTimeCode)
                    .keyboardType(.numberPad)
                
                Button {
                    viewModel.verifyCode(verificationCode)
                } label: {
                    Label(#localize("profile_code_verify"), systemImage: "checkmark.seal")
                }
                .buttonStyle(.plain)
                .disabled(verificationCode.isEmpty)
            }
            header: {
                Text(#localize("profile_code_code"))
            }
            footer: {
                Text("\(#localize("number")): \(viewModel.formattedNumber)")
            }
            
            Section {
                Button {
                    viewModel.showCallAlert = true
                } label: {
                    HStack {
                        Label(#localize("profile_code_request_call"), systemImage: "phone.badge.checkmark")
                        Spacer()
                        if !viewModel.callAvailable() {
                            Text(verbatim: "(") + Text(viewModel.callAvailableDate, style: .relative) +
                                Text(verbatim: ")")
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.callAvailable())
                
                Button(role: .destructive) {
                    viewModel.showAbortVerificationAlert = true
                } label: {
                    Label(#localize("profile_code_abort_verification"), systemImage: "xmark.seal")
                        .foregroundStyle(.red)
                }
            }
        }
        .task {
            viewModel.checkCallAvailability()
        }
        // Call alert
        .alert(#localize("call_me_title"), isPresented: $viewModel.showCallAlert) {
            Button {
                viewModel.requestCall()
            }
            label: {
                Text(#localize("ok"))
            }
            
            Button(role: .cancel) {
                // No-op
            } label: {
                Text(#localize("cancel"))
            }
        } message: {
            Text(#localize("call_me_message"))
        }
       
        // Abort alert
        .alert(#localize("abort_verification_message"), isPresented: $viewModel.showAbortVerificationAlert) {
            Button(role: .destructive) {
                viewModel.abortVerification()
            }
            label: {
                Text(#localize("abort_verification"))
            }
            
            Button(role: .cancel) {
                // No-op
            } label: {
                Text(#localize("cancel"))
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
