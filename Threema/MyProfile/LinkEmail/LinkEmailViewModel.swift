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

import Foundation

import ThreemaMacros

final class LinkEmailViewModel: ObservableObject {
    
    enum LinkingState {
        case determing
        case unlinked
        case verifying
        case linked
    }
    
    // State
    @Published var linkingState: LinkingState = .determing
    
    // Values
    @Published var email = ""
    @Published var serverName: String?

    // Alerts
    @Published var showInvalidEmailAlert = false
    @Published var showConfirmationAlert = false
    @Published var showAbortVerificationAlert = false
    
    // Error
    @Published var showError = false
    @Published var errorText = ""
    
    private let connector: ServerAPIConnector
    private let businessInjector: BusinessInjector
    private let identityStore: MyIdentityStore
    
    // MARK: - Lifecycle
    
    init(businessInjector: BusinessInjector = BusinessInjector.ui) {
        self.connector = ServerAPIConnector()
        self.businessInjector = businessInjector
        self.identityStore = businessInjector.myIdentityStore as! MyIdentityStore
   
        determineState()
        checkServerName()
    }
    
    private func determineState() {
        
        if identityStore.linkEmailPending {
            linkingState = .verifying
        }
        else if identityStore.linkedEmail != nil {
            linkingState = .linked
        }
        else {
            linkingState = .unlinked
        }
        
        if let linkedEmail = identityStore.linkedEmail {
            email = linkedEmail
        }
        
        // If we are pending we do the check
        if identityStore.linkEmailPending {
            connector.checkLinkEmailStatus(
                identityStore,
                email: identityStore.linkedEmail
            ) { [weak self] linked in
                // If we are linked, we update our state
                guard let self, linked else {
                    return
                }
                determineState()
            } onError: { _ in
                // No-op
            }
        }
    }
    
    private func checkServerName() {
        guard TargetManager.isOnPrem else {
            return
        }
        
        ServerInfoProviderFactory.makeServerInfoProvider()
            .directoryServer(ipv6: businessInjector.userSettings.enableIPv6) { [weak self] info, _ in
                guard let self else {
                    return
                }
                if let urlString = info?.url, let url = URL(string: urlString), let host = url.host {
                    serverName = host
                }
            }
    }
    
    // MARK: - Public functions
    
    func verifyEmail(_ email: String) {
        guard !email.isEmpty else {
            showInvalidEmailAlert = true
            return
        }
        self.email = email
        showConfirmationAlert = true
    }
    
    func linkEmail() {
        connector.linkEmail(with: identityStore, email: email) { _ in
            self.linkingState = .verifying
            NotificationPresenterWrapper.shared.present(type: .verificationEmailSent)
            NotificationCenter.default.post(name: NSNotification.Name(kLinkedEmailUIRefresh), object: nil)
        } onError: { [weak self] error in
            guard let self else {
                return
            }
            errorText = error?.localizedDescription ?? #localize("try_again")
            showError = true
        }
    }
    
    func abortVerification() {
        identityStore.linkEmailPending = false
        identityStore.linkedEmail = nil
        
        linkingState = .unlinked
        email = ""
        
        NotificationCenter.default.post(name: NSNotification.Name(kLinkedEmailUIRefresh), object: nil)
    }
    
    func unlinkEmail() {
        connector.linkEmail(with: identityStore, email: "") { [weak self] _ in
            self?.abortVerification()
        } onError: { [weak self] error in
            guard let self else {
                return
            }
            errorText = error?.localizedDescription ?? #localize("try_again")
            showError = true
        }
    }
}
