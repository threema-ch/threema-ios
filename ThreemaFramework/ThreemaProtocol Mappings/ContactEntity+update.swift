//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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
import ThreemaProtocols

extension ContactEntity {
    func update(
        syncContact: Sync_Contact,
        userDefinedProfilePicture: Data?,
        contactDefinedProfilePicture: Data?,
        entityManager: EntityManager,
        contactStore: ContactStoreProtocol
    ) {
        guard let managedObjectContext,
              entityManager.isEqualWithCurrentContext(managedObjectContext: managedObjectContext) else {
            fatalError("Managed object context mismatch")
        }

        guard syncContact.identity == identity else {
            fatalError("Threema identity mismatch")
        }

        if syncContact.hasAcquaintanceLevel {
            isContactHidden = syncContact.acquaintanceLevel == .group
        }

        if syncContact.hasContactDefinedProfilePicture {
            switch syncContact.contactDefinedProfilePicture.image {
            case .removed:
                contactImage = nil
            case .updated:
                let dbImageData = entityManager.entityCreator
                    .imageData()
                contactImage = dbImageData
                contactImage?.data = contactDefinedProfilePicture
            case .none:
                break
            }
        }

        if syncContact.hasCreatedAt {
            createdAt = syncContact.createdAtNullable?.date
        }

        if syncContact.hasFeatureMask {
            featureMask = NSNumber(value: syncContact.featureMask)
        }

        if syncContact.hasFirstName {
            firstName = syncContact.firstNameNullable
        }

        if syncContact.hasIdentityType {
            switch syncContact.identityType {
            case .regular:
                break
            case .work:
                contactStore
                    .addAsWork(identities: NSOrderedSet(array: [identity]), contactSyncer: nil)
            case .UNRECOGNIZED:
                break
            }
        }

        if syncContact.hasLastName {
            lastName = syncContact.lastNameNullable
        }

        if syncContact.hasNickname {
            publicNickname = syncContact.nicknameNullable
        }

        if syncContact.hasUserDefinedProfilePicture {
            switch syncContact.userDefinedProfilePicture.image {
            case .removed:
                imageData = nil
            case .updated:
                imageData = userDefinedProfilePicture
            case .none:
                break
            }
        }

        if syncContact.hasReadReceiptPolicyOverride {
            switch syncContact.readReceiptPolicyOverride.override {
            case .default:
                readReceipt = .default
            case let .policy(readReceiptPolicy):
                switch readReceiptPolicy {
                case .dontSendReadReceipt:
                    readReceipt = .doNotSend
                case .sendReadReceipt:
                    readReceipt = .send
                case .UNRECOGNIZED:
                    DDLogError("Unknown type of read receipt policy")
                }
            case .none:
                break
            }
        }

        if syncContact.hasSyncState {
            importedStatus = ImportedStatus(rawValue: syncContact.syncState.rawValue)!
        }

        if syncContact.hasTypingIndicatorPolicyOverride {
            switch syncContact.typingIndicatorPolicyOverride.override {
            case .default:
                typingIndicator = .default
            case let .policy(typingIndicatorPolicy):
                switch typingIndicatorPolicy {
                case .sendTypingIndicator:
                    typingIndicator = .send
                case .dontSendTypingIndicator:
                    typingIndicator = .doNotSend
                case .UNRECOGNIZED:
                    DDLogError("Unknown type of typing indicator policy")
                }
            case .none:
                break
            }
        }

        if syncContact.hasVerificationLevel {
            verificationLevel = NSNumber(integerLiteral: syncContact.verificationLevel.rawValue)
        }

        if syncContact.hasWorkVerificationLevel {
            switch syncContact.workVerificationLevel {
            case .none:
                workContact = false
            case .workSubscriptionVerified:
                workContact = true
            case .UNRECOGNIZED:
                break
            }
        }
    }
}
