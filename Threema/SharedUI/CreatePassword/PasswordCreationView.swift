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

struct PasswordCreationView: View {
    weak var coordinator: ProfileCoordinator?
    let title: String
    let footer: String
    
    let passwordCreated: (String) -> Void
    init(coordinator: ProfileCoordinator?, title: String, footer: String, passwordCreated: @escaping (String) -> Void) {
        self.coordinator = coordinator
        self.title = title
        self.footer = footer
        self.passwordCreated = passwordCreated
    }
    
    @State private var password = ""
    @State private var confirmationPassword = ""
    
    @State private var showLenghtAlert = false
    @State private var showMismatchAlert = false
    
    var body: some View {
    
        List {
            Section {
                SecureField(#localize("Password"), text: $password)
                SecureField(#localize("password_again"), text: $confirmationPassword)
            } header: {
                Text(#localize("Password"))
            }
            footer: {
                Text(footer)
            }
        }
        // Alerts
        .alert(#localize("password_mismatch_title"), isPresented: $showMismatchAlert) {
            Button(role: .cancel) {
                // No-op
            } label: {
                Text(#localize("ok"))
            }
        } message: {
            Text(#localize("password_mismatch_message"))
        }
        .alert(#localize("password_too_short_title"), isPresented: $showLenghtAlert) {
            Button(role: .cancel) {
                // No-op
            } label: {
                Text(#localize("ok"))
            }
        } message: {
            Text(#localize("password_too_short_message"))
        }
       
        // Navigationbar
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    coordinator?.dismiss()
                } label: {
                    Text(#localize("cancel"))
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    donePressed()
                } label: {
                    Text(#localize("Done"))
                        .disabled(password.isEmpty || confirmationPassword.isEmpty)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func donePressed() {
        if password != confirmationPassword {
            showMismatchAlert = true
            return
        }
        else if password.count < 8 {
            showLenghtAlert = true
            return
        }
        
        coordinator?.dismiss()
        passwordCreated(password)
    }
}

#Preview {
    PasswordCreationView(coordinator: nil, title: "Preview", footer: "Footer") { _ in }
}
