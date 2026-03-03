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
    
    private enum Field: Hashable, Equatable {
        case password
        case confirmation
    }
    
    @Environment(\.dismiss) private var dismiss
    
    @FocusState private var focus: Field?

    weak var coordinator: ProfileCoordinator?
    let title: String
    let footer: String
    let passwordCreateButton: String
    let onPasswordCreated: (String) -> Void
    let onDismiss: (() -> Void)?
    
    init(
        coordinator: ProfileCoordinator?,
        title: String,
        footer: String,
        passwordCreateButton: String,
        onPasswordCreated: @escaping (String) -> Void,
        onDismiss: (() -> Void)? = nil
    ) {
        self.coordinator = coordinator
        self.title = title
        self.footer = footer
        self.passwordCreateButton = passwordCreateButton
        self.onPasswordCreated = onPasswordCreated
        self.onDismiss = onDismiss
    }
    
    @State private var password = ""
    @State private var confirmationPassword = ""
    
    @State private var showLengthAlert = false
    @State private var showMismatchAlert = false
    
    var body: some View {
    
        List {
            Section {
                SecureField(#localize("Password"), text: $password)
                    .focused($focus, equals: .password)
                    .submitLabel(.next)
                    .onSubmit {
                        focus = .confirmation
                    }
                
                SecureField(#localize("password_again"), text: $confirmationPassword)
                    .focused($focus, equals: .confirmation)
            } header: {
                Text(#localize("safe_configure_choose_password_title"))
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
        .alert(#localize("password_too_short_title"), isPresented: $showLengthAlert) {
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
                    // swiftformat:disable preferKeyPath
                    let dismissAction = coordinator.map {
                        $0.dismiss
                    } ?? onDismiss ?? dismiss.callAsFunction
                    // swiftformat:enable preferKeyPath
                    
                    dismissAction()
                } label: {
                    Text(#localize("cancel"))
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    donePressed()
                } label: {
                    Text(passwordCreateButton)
                }
                .disabled(password.isEmpty || confirmationPassword.isEmpty)
            }
        }
        .onAppear {
            focus = .password
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
            showLengthAlert = true
            return
        }
        
        // swiftformat:disable preferKeyPath
        let dismissAction = coordinator.map {
            $0.dismiss
        } ?? onDismiss ?? dismiss.callAsFunction
        dismissAction()
        // swiftformat:enable preferKeyPath
        
        onPasswordCreated(password)
    }
}

#Preview {
    NavigationView {
        PasswordCreationView(
            coordinator: nil,
            title: "Preview",
            footer: "Footer",
            passwordCreateButton: "Export"
        ) { _ in
            // no-op
        }
    }
}
