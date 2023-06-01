//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

public typealias ThreemaIdentity = String

/// Business representation of a Threema Contact
public class Contact: NSObject {

    // Tokens for entity subscription, will be removed when is deallocated
    private var subscriptionToken: EntityObserver.SubscriptionToken?

    /// Initialize Contact properties and subscribe ContactEntity on EntityObserver for updates.
    /// Note: Contact properties will be only refreshed if it's ContactEntity object already saved in Core Data.
    ///
    /// - Parameter contactEntity: Core Data object
    @objc init(contactEntity: ContactEntity) {
        self.identity = contactEntity.identity
        self.publicKey = contactEntity.publicKey
        self.publicNickname = contactEntity.publicNickname
        self.firstName = contactEntity.firstName
        self.lastName = contactEntity.lastName
        self.verificationLevel = contactEntity.verificationLevel.intValue
        self.state = contactEntity.state?.intValue ?? kStateInactive
        self.isWorkContact = contactEntity.isWorkContact()

        super.init()

        // Subscribe contact entity for DB updates or deletion
        self.subscriptionToken = EntityObserver.shared.subscribe(
            managedObject: contactEntity
        ) { [weak self] managedObject, reason in
            guard let contactEntity = managedObject as? ContactEntity else {
                DDLogError("Wrong type, should be ContactEntity")
                return
            }
            guard self?.identity == contactEntity.identity, self?.publicKey == contactEntity.publicKey else {
                DDLogError("Identity or public key mismatch")
                return
            }

            switch reason {
            case .deleted:
                if let deleted = self?.willBeDeleted, !deleted {
                    self?.willBeDeleted = true
                }
            case .updated:
                if self?.publicNickname != contactEntity.publicNickname {
                    self?.publicNickname = contactEntity.publicNickname
                }
                if self?.firstName != contactEntity.firstName {
                    self?.firstName = contactEntity.firstName
                }
                if self?.lastName != contactEntity.lastName {
                    self?.lastName = contactEntity.lastName
                }
                if self?.verificationLevel != contactEntity.verificationLevel.intValue {
                    self?.verificationLevel = contactEntity.verificationLevel.intValue
                }
                let newState = contactEntity.state?.intValue ?? kStateInactive
                if self?.state != newState {
                    self?.state = newState
                }
                if self?.isWorkContact != contactEntity.isWorkContact() {
                    self?.isWorkContact = contactEntity.isWorkContact()
                }
            }
        }
    }

    /// This will be set to `true` when a contact is in the process to be deleted.
    ///
    /// This can be used to detect deletion in KVO-observers
    public private(set) dynamic var willBeDeleted = false

    @objc public private(set) dynamic var identity: ThreemaIdentity
    public private(set) var publicKey: Data
    @objc public private(set) dynamic var firstName: String?
    @objc public private(set) dynamic var lastName: String?
    @objc public private(set) dynamic var publicNickname: String?
    public private(set) var verificationLevel = 0
    @objc public private(set) dynamic var state = 0

    public var isActive: Bool {
        state == kStateActive
    }

    @objc public dynamic var displayName: String {
        var value = String(ContactUtil.name(fromFirstname: firstName, lastname: lastName) ?? "")

        if value.isEmpty, let publicNickname = publicNickname, publicNickname != identity {
            value = "~\(publicNickname)"
        }

        if value.isEmpty {
            value = identity
        }

        switch state {
        case kStateInactive:
            value = "\(value) (\(BundleUtil.localizedString(forKey: "inactive")))"
        case kStateInvalid:
            value = "\(value) (\(BundleUtil.localizedString(forKey: "invalid")))"
        default:
            break
        }

        if value.isEmpty {
            DDLogError(
                "Display name is marked as nonnull and we should have something to show. Falling back to (unknown)."
            )
            value = BundleUtil.localizedString(forKey: "(unknown)")
        }

        return value
    }
    
    // Needed for KVO on `displayName`: https://stackoverflow.com/a/51108007
    @objc public class var keyPathsForValuesAffectingDisplayName: Set<String> {
        [
            #keyPath(firstName),
            #keyPath(lastName),
            #keyPath(publicNickname),
            #keyPath(state),
            #keyPath(identity),
        ]
    }

    /// Shorter version of `displayName` if available
    var shortDisplayName: String {
        // This is an "op-in" feature
        guard ThreemaApp.current == .threema || ThreemaApp.current == .red else {
            return displayName
        }

        if let firstName = firstName, !firstName.isEmpty {
            return firstName
        }

        return displayName
    }

    // This only means it's a verified contact from the admin (in the same work package)
    // To check if this contact is a work ID, use the workidentities list in usersettings
    // bad naming because of the history...
    private(set) var isWorkContact: Bool

    private var workAdjustedVerificationLevel: Int {
        var myVerificationLevel = verificationLevel
        if isWorkContact {
            if myVerificationLevel == kVerificationLevelServerVerified || myVerificationLevel ==
                kVerificationLevelFullyVerified {
                myVerificationLevel += 2
            }
            else {
                myVerificationLevel = kVerificationLevelWorkVerified
            }
        }

        return myVerificationLevel
    }

    var verificationLevelImageSmall: UIImage {
        switch workAdjustedVerificationLevel {
        case 0: return StyleKit.verificationSmall0
        case 1: return StyleKit.verificationSmall1
        case 2: return StyleKit.verificationSmall2
        case 3: return StyleKit.verificationSmall3
        case 4: return StyleKit.verificationSmall4
        default: return StyleKit.verificationSmall0
        }
    }

    var verificationLevelImage: UIImage {
        switch workAdjustedVerificationLevel {
        case 0: return StyleKit.verification0
        case 1: return StyleKit.verification1
        case 2: return StyleKit.verification2
        case 3: return StyleKit.verification3
        case 4: return StyleKit.verification4
        default: return StyleKit.verification0
        }
    }

    var verificationLevelImageBig: UIImage {
        switch workAdjustedVerificationLevel {
        case 0: return StyleKit.verificationBig0
        case 1: return StyleKit.verificationBig1
        case 2: return StyleKit.verificationBig2
        case 3: return StyleKit.verificationBig3
        case 4: return StyleKit.verificationBig4
        default: return StyleKit.verificationBig0
        }
    }

    /// Localized string of verification level usable for accessibility
    var verificationLevelAccessibilityLabel: String {
        BundleUtil.localizedString(forKey: "level\(workAdjustedVerificationLevel)_title")
    }

    // MARK: Comparing function

    public func isEqual(to object: Any?) -> Bool {
        guard let object = object as? Contact else {
            return false
        }

        return willBeDeleted == object.willBeDeleted &&
            identity == object.identity &&
            publicKey == object.publicKey &&
            firstName == object.firstName &&
            lastName == object.lastName &&
            publicNickname == object.publicNickname &&
            verificationLevel == object.verificationLevel &&
            state == object.state &&
            isWorkContact == object.isWorkContact
    }
}

extension Set<Contact> {
    // Comparing contacts independent of the oder
    func contactsEqual(to other: Set<Contact>) -> Bool {
        count == other.count &&
            contains(where: { le in
                var equal = false
                for re in other {
                    if le.isEqual(to: re) {
                        equal = true
                        break
                    }
                }
                return equal
            })
    }
}

extension ThreemaIdentity {
    var isValid: Bool {
        count == ThreemaProtocol.identityLength
    }
}
