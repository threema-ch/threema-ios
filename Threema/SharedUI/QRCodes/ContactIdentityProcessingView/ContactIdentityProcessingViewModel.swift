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

import CocoaLumberjackSwift
import Observation
import ThreemaEssentials
import ThreemaMacros

@MainActor
@Observable
final class ContactIdentityProcessingViewModel {

    // MARK: - Public types

    struct AlertData: Identifiable {
        let id = UUID()
        let title: String
        let message: String?
    }

    // MARK: - Public properties

    var alert: AlertData?
    var onCompletion: ((ContactEntity?) -> Void)?

    // MARK: - Private types

    private var contactVerified: ContactEntity?
    private let expectedIdentity: ThreemaIdentity?
    private let scannedIdentity: ThreemaIdentity
    private let scannedPublicKey: Data
    private let scannedExpirationDate: Date?

    private let systemFeedbackManager: SystemFeedbackManagerProtocol
    private let serverAPIConnector = ServerAPIConnector()

    private let contactStore = ContactStore.shared()
    private let entityFetcher = BusinessInjector.ui.entityManager.entityFetcher
    private let identityStore = MyIdentityStore.shared()
    private let notificationCenter = NotificationCenter.default
    private let notificationPresenterWrapper = NotificationPresenterWrapper.shared
    private let dateProvider: () -> Date

    // MARK: - Lifecycle

    init(
        expectedIdentity: ThreemaIdentity?,
        scannedIdentity: ThreemaIdentity,
        scannedPublicKey: Data,
        scannedExpirationDate: Date?,
        systemFeedbackManager: SystemFeedbackManagerProtocol,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.expectedIdentity = expectedIdentity
        self.scannedIdentity = scannedIdentity
        self.scannedPublicKey = scannedPublicKey
        self.scannedExpirationDate = scannedExpirationDate
        self.systemFeedbackManager = systemFeedbackManager
        self.dateProvider = dateProvider
    }

    // MARK: - Public methods

    func onAppear() {
        processContactIdentityData(
            scannedIdentity: scannedIdentity,
            scannedPublicKey: scannedPublicKey,
            scannedExpirationDate: scannedExpirationDate,
            expectedIdentity: expectedIdentity
        )
    }

    func alertOKButtonTapped() {
        closeScreen()
    }

    // MARK: - Private methods

    private func processContactIdentityData(
        scannedIdentity: ThreemaIdentity,
        scannedPublicKey: Data,
        scannedExpirationDate: Date?,
        expectedIdentity: ThreemaIdentity?
    ) {
        if let expectedIdentity, scannedIdentity != expectedIdentity {
            alertIdentitiesNotMatching()
        }
        else if isEqualToOwnIdentity(identity: scannedIdentity) {
            alertScanningOwnIdentity()
        }
        else if isIdentityExpired(date: scannedExpirationDate) {
            alertIdentityExpiration()
        }
        else if let existingContact = existingContact(for: scannedIdentity) {
            if existingContact.publicKey != scannedPublicKey {
                alertExistingContactPublicKeyMismatch(identity: scannedIdentity.rawValue)
            }
            else {
                upgradeContactVerificationLevel(contact: existingContact)
            }
        }
        else {
            addContact(identity: scannedIdentity, key: scannedPublicKey)
        }
    }

    private func upgradeContactVerificationLevel(contact: ContactEntity) {
        let verified = Int32(VerificationLevel.fullyVerified.rawValue)
        contactStore.upgrade(contact, toVerificationLevel: verified)
        completeVerifiedContact(contact)
    }

    private func isIdentityExpired(date: Date?) -> Bool {
        guard let date else {
            return false
        }
        let now = dateProvider()
        return date < now
    }

    private func isEqualToOwnIdentity(identity: ThreemaIdentity) -> Bool {
        identity.rawValue == identityStore.identity
    }

    private func existingContact(for identity: ThreemaIdentity) -> ContactEntity? {
        entityFetcher.contactEntity(for: identity.rawValue)
    }

    private func addContact(identity: ThreemaIdentity, key: Data) {
        Task {
            do {
                let info = try await serverAPIConnector.fetchIdentityInfo(identity.rawValue)
                if info.publicKey != key {
                    alertServerPublicKeyMismatch(identity: identity.rawValue)
                }
                else {
                    persistContact(
                        identity: identity,
                        publicKey: info.publicKey,
                        state: info.state,
                        type: info.type,
                        featureMask: info.featureMask
                    )
                }
            }
            catch {
                if (error as NSError).domain == NSURLErrorDomain, (error as NSError).code == 404 {
                    alertIdentityNotFound()
                }
                else {
                    alertGenericError(error: error)
                }
            }
        }
    }

    private func persistContact(
        identity: ThreemaIdentity,
        publicKey: Data,
        state: NSNumber?,
        type: NSNumber?,
        featureMask: NSNumber?
    ) {
        let verificationLevel = Int32(VerificationLevel.fullyVerified.rawValue)
        contactStore.addContact(
            with: identity.rawValue,
            publicKey: publicKey,
            cnContactID: nil,
            verificationLevel: verificationLevel,
            state: state,
            type: type,
            featureMask: featureMask,
            acquaintanceLevel: .direct,
            alerts: true
        ) { [weak self] contact in
            guard let self else {
                return
            }
            guard let contact = contact as? ContactEntity else {
                alertAddContactStoreError()
                return
            }
            completeVerifiedContact(contact)
        }
    }

    private func completeVerifiedContact(_ contact: ContactEntity) {
        systemFeedbackManager.playSuccessSound()
        contactVerified = contact
        closeScreen()
    }

    private func closeScreen() {
        if let contactVerified {
            contactStore.synchronizeAddressBook(forceFullSync: true, ignoreMinimumInterval: false, onCompletion: nil)
            notificationPresenterWrapper.present(type: .idVerified)
            onCompletion?(contactVerified)
        }
        else {
            onCompletion?(nil)
        }
    }

    private func alertIdentitiesNotMatching() {
        DDLogError("Identity not matching expected identity!")
        alert = AlertData(
            title: #localize("scanned_identity_mismatch_title"),
            message: #localize("scanned_identity_mismatch_message")
        )
    }

    private func alertScanningOwnIdentity() {
        DDLogError("Scanning own identity!")
        alert = AlertData(
            title: #localize("scanned_own_identity_title"),
            message: nil
        )
    }

    private func alertIdentityExpiration() {
        DDLogError("Identity expired!")
        alert = AlertData(
            title: #localize("scan_code_expired_title"),
            message: #localize("scan_code_expired_message")
        )
    }

    private func alertExistingContactPublicKeyMismatch(identity: String) {
        DDLogError("Scanned public key doesn't match for existing identity \(identity)!")
        alert = AlertData(
            title: #localize("public_key_mismatch_title"),
            message: #localize("public_key_mismatch_message")
        )
    }

    private func alertServerPublicKeyMismatch(identity: String) {
        DDLogError("Scanned public key doesn't match key returned by server for \(identity)!")
        alert = AlertData(
            title: #localize("public_key_server_mismatch_title"),
            message: #localize("public_key_server_mismatch_message")
        )
    }

    private func alertIdentityNotFound() {
        alert = AlertData(
            title: #localize("identity_not_found_title"),
            message: #localize("identity_not_found_message")
        )
    }

    private func alertAddContactStoreError() {
        alert = AlertData(
            title: #localize("scan_id_add_contact_failed_title"),
            message: #localize("scan_id_add_contact_failed_message")
        )
    }

    private func alertGenericError(error: any Error) {
        alert = AlertData(
            title: error.localizedDescription,
            message: (error as NSError).localizedFailureReason ?? ""
        )
    }
}
