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
import ThreemaEssentials
import ThreemaProtocols

/// Business representation of a Threema Contact
public class Contact: NSObject {
    
    // These strings are used as static properties for performance reasons
    private static let inactiveString = "inactive".localized
    private static let invalidString = "invalid".localized
    private static let unknownString = "(unknown)".localized
    private static let workAdjustedVerificationLevelString0 = "level0_title".localized
    private static let workAdjustedVerificationLevelString1 = "level1_title".localized
    private static let workAdjustedVerificationLevelString2 = "level2_title".localized
    private static let workAdjustedVerificationLevelString3 = "level3_title".localized
    private static let workAdjustedVerificationLevelString4 = "level4_title".localized

    // MARK: - Observation
    
    // Tokens for entity subscription, will be removed when is deallocated
    private var subscriptionToken: EntityObserver.SubscriptionToken?

    /// This will be set to `true` when a contact is in the process to be deleted.
    ///
    /// This can be used to detect deletion in KVO-observers
    @objc public private(set) dynamic var willBeDeleted = false
    
    // Needed for KVO on `displayName`: https://stackoverflow.com/a/51108007
    @objc public class var keyPathsForValuesAffectingDisplayName: Set<String> {
        [
            #keyPath(firstName),
            #keyPath(lastName),
            #keyPath(publicNickname),
            #keyPath(state),
            #keyPath(objcIdentity),
        ]
    }
    
    @objc public private(set) dynamic var state = 0
    @objc public private(set) dynamic var firstName: String?
    @objc public private(set) dynamic var lastName: String?
    @objc public private(set) dynamic var publicNickname: String?
    @objc public private(set) dynamic var verificationLevel = 0
    @objc public private(set) dynamic var featureMask: Int
    @objc public private(set) dynamic lazy var profilePicture: UIImage = resolveProfilePicture()

    @objc public private(set) dynamic var displayName: String {
        get {
            resolveDisplayName()
        }
        set {
            // No-op
        }
    }
    
    @objc public private(set) dynamic var readReceipt: ReadReceipt
    @objc public private(set) dynamic var typingIndicator: TypingIndicator

    // MARK: - Public properties

    public let identity: ThreemaIdentity
    @objc(identity) public let objcIdentity: String
    
    let publicKey: Data
    
    public var isActive: Bool {
        state == kStateActive
    }
    
    // If true when acquaintance level is group or deleted
    @objc public private(set) dynamic var isHidden: Bool

    // This only means it's a verified contact from the admin (in the same work package)
    // To check if this contact is a work ID, use the work identities list in user settings
    // bad naming because of the history...
    private(set) var isWorkContact: Bool

    public let showOtherTypeIcon: Bool
    
    /// Shorter version of `displayName` if available
    var shortDisplayName: String {
        // This is an "opt-in" feature
        guard ThreemaApp.current == .threema || ThreemaApp.current == .green else {
            return displayName
        }

        if let firstName, !firstName.isEmpty {
            return firstName
        }

        return displayName
    }
    
    public var hasGatewayID: Bool {
        identity.isGatewayID
    }
    
    public var forwardSecurityMode: ForwardSecurityMode {
        
        guard isForwardSecurityAvailable else {
            return .none
        }
        
        do {
            let businessInjector = BusinessInjector()
            guard let dhSession = try businessInjector.dhSessionStore.bestDHSession(
                myIdentity: MyIdentityStore.shared().identity,
                peerIdentity: identity.string
            ) else {
                return .none
            }
            
            let state = try dhSession.state
            
            switch state {
            case .L20:
                return .twoDH
            case .RL44:
                return .fourDH
            case .R20:
                return .twoDH
            case .R24:
                return .twoDH
            }
        }
        catch {
            DDLogError("Could not get ForwardSecurityMode for contact with identity: \(identity).")
            return .none
        }
    }
    
    public private(set) var usesNonGeneratedProfilePicture = false

    // MARK: - Private properties
    
    private var isForwardSecurityAvailable: Bool

    private lazy var idColor: UIColor = IDColor.forData(Data(identity.string.utf8))

    /// Either first character of first and last name in order depending of the user setting, or first two characters of
    /// public
    /// nickname or of ID if no name is specified.
    private var initials: String {
        
        // If we have both a non empty first and last name
        if let firstName = firstName?.replacingOccurrences(of: " ", with: ""),
           let lastName = lastName?.replacingOccurrences(of: " ", with: ""),
           !firstName.isEmpty,
           !lastName.isEmpty {
            if UserSettings.shared().displayOrderFirstName {
                return String(firstName.prefix(1)) + String(lastName.prefix(1)).uppercased()
            }
            else {
                return String(lastName.prefix(1)) + String(firstName.prefix(1)).uppercased()
            }
        }
        
        // If we have a non empty first name we use the first two letters
        if let firstName = firstName?.replacingOccurrences(of: " ", with: ""),
           !firstName.isEmpty {
            return String(firstName.prefix(2)).uppercased()
        }
        
        // If we have a non empty first last we use the first two letters
        if let lastName = lastName?.replacingOccurrences(of: " ", with: ""),
           !lastName.isEmpty {
            return String(lastName.prefix(2)).uppercased()
        }
        
        // Public nickname
        if let publicNickname = publicNickname?.replacingOccurrences(of: " ", with: ""),
           !publicNickname.isEmpty {
            return String(publicNickname.prefix(2)).uppercased()
        }
        
        // ID
        return String(identity.string.prefix(2)).uppercased()
    }
    
    /// Image data sent from threema. For KVO, observe `profilePicture` directly.
    private var threemaImageData: Data? {
        didSet {
            updateProfilePicture()
        }
    }
    
    /// Image data set from Contacts. For KVO, observe `profilePicture` directly.
    private var contactImageData: Data? {
        didSet {
            updateProfilePicture()
        }
    }
    
    // MARK: - Lifecycle
    
    /// Initialize Contact properties and subscribe ContactEntity on EntityObserver for updates.
    /// Note: Contact properties will be only refreshed if it's ContactEntity object already saved in Core Data.
    ///
    /// - Parameter contactEntity: Core Data object
    @objc public init(contactEntity: ContactEntity) {
        self.identity = ThreemaIdentity(contactEntity.identity)
        self.objcIdentity = contactEntity.identity
        self.publicKey = contactEntity.publicKey
        self.publicNickname = contactEntity.publicNickname
        self.firstName = contactEntity.firstName
        self.lastName = contactEntity.lastName
        self.verificationLevel = contactEntity.verificationLevel.intValue
        self.state = contactEntity.state?.intValue ?? kStateInactive
        self.isHidden = contactEntity.isContactHidden
        self.isWorkContact = contactEntity.isWorkContact()
        self.showOtherTypeIcon = contactEntity.showOtherThreemaTypeIcon
        self.isForwardSecurityAvailable = contactEntity.isForwardSecurityAvailable()
        self.featureMask = contactEntity.featureMask.intValue
        self.threemaImageData = contactEntity.contactImage?.data
        self.contactImageData = contactEntity.imageData
        self.readReceipt = contactEntity.readReceipt
        self.typingIndicator = contactEntity.typingIndicator
        
        super.init()

        // Update tracking
        subscribeForContactEntityChanges(contactEntity: contactEntity)
        addOtherObservers()
    }

    public func profilePictureForGroupCalls() -> UIImage {
        updateProfilePicture()
        
        if usesNonGeneratedProfilePicture {
            return profilePicture
        }
        return ProfilePictureGenerator.generateGroupCallImage(initials: initials, color: idColor)
    }
    
    public func generatedProfilePicture() -> UIImage {
        ProfilePictureGenerator.generateImage(
            for: hasGatewayID ? .gateway : .contact(letters: initials),
            color: idColor
        )
    }
    
    // MARK: - Private functions
    
    private func addOtherObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateProfilePicture),
            name: Notification.Name(kNotificationShowProfilePictureChanged),
            object: nil
        )
    }

    private func subscribeForContactEntityChanges(contactEntity: ContactEntity) {
        
        subscriptionToken = EntityObserver.shared.subscribe(
            managedObject: contactEntity
        ) { [weak self] managedObject, reason in
            guard let self, let contactEntity = managedObject as? ContactEntity else {
                DDLogError("Wrong type, should be ContactEntity")
                return
            }

            switch reason {
            case .deleted:
                if !willBeDeleted {
                    willBeDeleted = true
                }
            case .updated:
                guard identity == ThreemaIdentity(contactEntity.identity),
                      publicKey == contactEntity.publicKey else {
                    DDLogError("Identity or public key mismatch")
                    return
                }

                if publicNickname != contactEntity.publicNickname {
                    publicNickname = contactEntity.publicNickname
                }
                if firstName != contactEntity.firstName {
                    firstName = contactEntity.firstName
                }
                if lastName != contactEntity.lastName {
                    lastName = contactEntity.lastName
                }
                if verificationLevel != contactEntity.verificationLevel.intValue {
                    verificationLevel = contactEntity.verificationLevel.intValue
                }
                let newState = contactEntity.state?.intValue ?? kStateInactive
                if state != newState {
                    state = newState
                }
                if isHidden != contactEntity.isContactHidden {
                    isHidden = contactEntity.isContactHidden
                }
                if isWorkContact != contactEntity.isWorkContact() {
                    isWorkContact = contactEntity.isWorkContact()
                }
                if featureMask != contactEntity.featureMask.intValue {
                    featureMask = contactEntity.featureMask.intValue
                    isForwardSecurityAvailable = contactEntity.isForwardSecurityAvailable()
                }
                if isWorkContact != contactEntity.isWorkContact() {
                    isWorkContact = contactEntity.isWorkContact()
                }
                if threemaImageData != contactEntity.contactImage?.data {
                    threemaImageData = contactEntity.contactImage?.data
                }
                if contactImageData != contactEntity.imageData {
                    contactImageData = contactEntity.imageData
                }
                if readReceipt != contactEntity.readReceipt {
                    readReceipt = contactEntity.readReceipt
                }
                if typingIndicator != contactEntity.typingIndicator {
                    typingIndicator = contactEntity.typingIndicator
                }
            }
        }
    }
    
    private func resolveDisplayName() -> String {
        var value = String(ContactUtil.name(fromFirstname: firstName, lastname: lastName) ?? "")

        if value.isEmpty, let publicNickname, !publicNickname.isEmpty, publicNickname != identity.string {
            value = "~\(publicNickname)"
        }

        if value.isEmpty {
            value = identity.string
        }

        switch state {
        case kStateInactive:
            value = "\(value) (\(Contact.inactiveString))"
        case kStateInvalid:
            value = "\(value) (\(Contact.invalidString))"
        default:
            break
        }

        if value.isEmpty {
            DDLogError(
                "Display name is marked as nonnull and we should have something to show. Falling back to (unknown)."
            )
            value = Contact.unknownString
        }

        return value
    }
   
    @objc private func updateProfilePicture() {
        profilePicture = resolveProfilePicture()
    }
    
    private func resolveProfilePicture() -> UIImage {
        
        // If `showProfilePictures` is enabled, we prioritize the image sent by the contact, else we use the image
        // set from contacts, if one was set.
        let imageData: Data? =
            if UserSettings.shared().showProfilePictures,
            let data = threemaImageData {
                data
            }
            else {
                contactImageData
            }
        
        // If no data was found, we generate a profile picture
        if let imageData, let image = UIImage(data: imageData) {
            usesNonGeneratedProfilePicture = true
            return image
        }
        else {
            usesNonGeneratedProfilePicture = false
            return ProfilePictureGenerator.generateImage(
                for: hasGatewayID ? .gateway : .contact(letters: initials),
                color: idColor
            )
        }
    }

    // MARK: - Verification level

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
        case 0: StyleKit.verificationSmall0
        case 1: StyleKit.verificationSmall1
        case 2: StyleKit.verificationSmall2
        case 3: StyleKit.verificationSmall3
        case 4: StyleKit.verificationSmall4
        default: StyleKit.verificationSmall0
        }
    }

    var verificationLevelImage: UIImage {
        switch workAdjustedVerificationLevel {
        case 0: StyleKit.verification0
        case 1: StyleKit.verification1
        case 2: StyleKit.verification2
        case 3: StyleKit.verification3
        case 4: StyleKit.verification4
        default: StyleKit.verification0
        }
    }

    var verificationLevelImageBig: UIImage {
        switch workAdjustedVerificationLevel {
        case 0: StyleKit.verificationBig0
        case 1: StyleKit.verificationBig1
        case 2: StyleKit.verificationBig2
        case 3: StyleKit.verificationBig3
        case 4: StyleKit.verificationBig4
        default: StyleKit.verificationBig0
        }
    }

    /// Localized string of verification level usable for accessibility
    var verificationLevelAccessibilityLabel: String {
        switch workAdjustedVerificationLevel {
        case 0:
            Contact.workAdjustedVerificationLevelString0
        case 1:
            Contact.workAdjustedVerificationLevelString1
        case 2:
            Contact.workAdjustedVerificationLevelString2
        case 3:
            Contact.workAdjustedVerificationLevelString3
        case 4:
            Contact.workAdjustedVerificationLevelString4
        default:
            Contact.workAdjustedVerificationLevelString0
        }
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
            profilePicture.pngData() == object.profilePicture.pngData() &&
            threemaImageData == object.threemaImageData &&
            contactImageData == object.contactImageData &&
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
