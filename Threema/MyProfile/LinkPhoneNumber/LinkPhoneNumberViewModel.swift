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

final class LinkPhoneNumberViewModel: ObservableObject {
   
    enum LinkingState {
        case determing
        case unlinked
        case verifying
        case linked
    }
    
    // State
    @Published var linkingState: LinkingState = .determing

    // Values
    @Published var normalizedNumber = ""
    @Published var formattedNumber = ""
    @Published var serverName: String?
    @Published var callAvailableDate = Date.now
    
    // Alerts
    @Published var showInvalidPhoneNumberAlert = false
    @Published var showConfirmationAlert = false
    @Published var showCallAlert = false
    @Published var showAbortVerificationAlert = false
    
    // Error
    @Published var showError = false
    @Published var errorText = ""

    private let connector: ServerAPIConnector
    private let businessInjector: BusinessInjector
    private let identityStore: MyIdentityStore
    private lazy var normalizer = PhoneNumberNormalizer.sharedInstance()
    
    // UI
    lazy var phoneNumberPlaceholder = normalizer?
        .examplePhoneNumber(forRegion: PhoneNumberNormalizer.userRegion()) ?? ""
    
    private var callTimer: Timer?
    
    // MARK: - Lifecycle

    init(businessInjector: BusinessInjector = BusinessInjector.ui) {
        self.connector = ServerAPIConnector()
        self.businessInjector = businessInjector
        self.identityStore = businessInjector.myIdentityStore as! MyIdentityStore
   
        determineState()
        checkServerName()
    }
    
    private func determineState() {
        if identityStore.linkMobileNoPending {
            linkingState = .verifying
        }
        else if identityStore.linkedMobileNo != nil {
            linkingState = .linked
        }
        else {
            linkingState = .unlinked
        }
        
        if let number = identityStore.linkedMobileNo {
            formatPhoneNumber(number)
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
    
    func verifyPhoneNumber(_ phoneNumber: String) {
        guard !phoneNumber.isEmpty else {
            showInvalidPhoneNumberAlert = true
            return
        }
        
        formatPhoneNumber(phoneNumber)
        
        guard normalizedNumber != "", formattedNumber != "" else {
            showInvalidPhoneNumberAlert = true
            return
        }

        showConfirmationAlert = true
    }
    
    func linkPhoneNumber() {
        connector.linkMobileNo(with: identityStore, mobileNo: normalizedNumber) { _ in
            self.linkingState = .verifying
            NotificationCenter.default.post(name: NSNotification.Name(kLinkedPhoneUIRefresh), object: nil)
        } onError: { [weak self] error in
            guard let self else {
                return
            }
            errorText = error?.localizedDescription ?? #localize("try_again")
            showError = true
        }
    }
    
    func verifyCode(_ code: String) {
        connector.linkMobileNo(with: identityStore, code: code) { [weak self] _ in
            guard let self else {
                return
            }
            
            linkingState = .linked
            NotificationCenter.default.post(name: NSNotification.Name(kLinkedPhoneUIRefresh), object: nil)

        } onError: { [weak self] error in
            guard let self else {
                return
            }
            errorText = error?.localizedDescription ?? #localize("try_again")
            showError = true
        }
    }
    
    func requestCall() {
        connector.linkMobileNoRequestCall(with: identityStore) {
            // No-op
        } onError: { [weak self] error in
            guard let self else {
                return
            }
            errorText = error?.localizedDescription ?? #localize("try_again")
            showError = true
        }
    }
    
    func abortVerification() {
        identityStore.linkMobileNoPending = false
        identityStore.linkMobileNoStartDate = nil
        identityStore.linkMobileNoVerificationID = nil
        identityStore.linkedMobileNo = nil
        
        linkingState = .unlinked
        formattedNumber = ""
        normalizedNumber = ""
        callAvailableDate = .now
        
        NotificationCenter.default.post(name: NSNotification.Name(kLinkedPhoneUIRefresh), object: nil)
    }
    
    func unlinkPhoneNumber() {
        connector.linkMobileNo(with: identityStore, mobileNo: "") { [weak self] _ in
            self?.abortVerification()
        } onError: { [weak self] error in
            guard let self else {
                return
            }
            errorText = error?.localizedDescription ?? #localize("try_again")
            showError = true
        }
    }
    
    func checkCallAvailability() {
        guard let linkStartDate = identityStore.linkMobileNoStartDate else {
            return
        }
        
        callAvailableDate = linkStartDate.addingTimeInterval(600)
        
        if !callAvailable() {
            callTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                
                guard let self else {
                    return
                }
                
                if callAvailable() {
                    callAvailableDate = Date.now
                    callTimer?.invalidate()
                    callTimer = nil
                }
            }
        }
    }
    
    func callAvailable() -> Bool {
        callAvailableDate < Date.now
    }
    
    // MARK: - Private functions
    
    private func formatPhoneNumber(_ phoneNumber: String) {
        var formatted: NSString?
        let normalized = normalizer?.phoneNumber(
            toE164: phoneNumber,
            withDefaultRegion: PhoneNumberNormalizer.userRegion(),
            prettyFormat: &formatted
        )
        
        guard let normalized, let formatted else {
            return
        }
        
        normalizedNumber = normalized
        formattedNumber = formatted as String
    }
}
