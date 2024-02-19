//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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

import CocoaLumberjackSwift
import Foundation
import ThreemaFramework

class SettingsViewModel: ObservableObject {
    @Published var navigator = Navigator()

    var displayFeedback: Bool {
        switch ThreemaEnvironment.env() {
        case .appStore:
            return false
        case .testFlight:
            if ThreemaApp.current == .red || ThreemaApp.current == .workRed || ThreemaApp.current == .onPrem {
                return false
            }
            return true
        case .xcode:
            return true
        }
    }
    
    var displayDevSettings: Bool {
        switch ThreemaEnvironment.env() {
        case .appStore:
            return false
        case .testFlight:
            if ThreemaApp.current == .red || ThreemaApp.current == .workRed {
                return true
            }
            return false
        case .xcode:
            return true
        }
    }
    
    func giveFeedback() {
        if let contact = BusinessInjector().entityManager.entityFetcher
            .contact(for: Constants.betaFeedbackIdentity) {
            showConversation(for: contact)
        }
        else {
            BusinessInjector().contactStore.addContact(
                with: Constants.betaFeedbackIdentity,
                verificationLevel: Int32(kVerificationLevelUnverified)
            ) { [self] contact, _ in
                guard let contact else {
                    DDLogError("Can't add \(Constants.betaFeedbackIdentity) as contact")
                    return
                }
                
                showConversation(for: contact)
            } onError: { error in
                DDLogError("Can't add \(Constants.betaFeedbackIdentity) as contact \(error)")
            }
        }
    }
    
    private func showConversation(for contact: ContactEntity) {
        let info = [
            kKeyContact: contact,
            kKeyForceCompose: NSNumber(booleanLiteral: true),
            kKeyText: "Version: \(ThreemaUtility.clientVersionWithMDM)",
        ] as [String: Any]
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name(rawValue: kNotificationShowConversation),
                object: nil,
                userInfo: info
            )
        }
    }
}
