//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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
import ThreemaMacros
import ThreemaProtocols

/// Business representation of a Threema Contact
public class Contact: NSObject {
    
    // These strings are used as static properties for performance reasons
    private static let inactiveString = #localize("inactive")
    private static let invalidString = #localize("invalid")
    private static let unknownString = #localize("(unknown)")
    private static let workAdjustedVerificationLevelString0 = #localize("level0_title")
    private static let workAdjustedVerificationLevelString1 = #localize("level1_title")
    private static let workAdjustedVerificationLevelString2 = #localize("level2_title")
    private static let workAdjustedVerificationLevelString3 = #localize("level3_title")
    private static let workAdjustedVerificationLevelString4 = #localize("level4_title")

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
    
    @objc public private(set) dynamic var state: ContactEntity.ContactState = .active
    @objc public private(set) dynamic var firstName: String?
    @objc public private(set) dynamic var lastName: String?
    @objc public private(set) dynamic var csi: String?
    @objc public private(set) dynamic var jobTitle: String?
    @objc public private(set) dynamic var department: String?
    @objc public private(set) dynamic var publicNickname: String?
    @objc public private(set) dynamic var verificationLevel: ContactEntity.VerificationLevel = .unverified
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
    
    @objc public private(set) dynamic var readReceipt: ContactEntity.ReadReceipt
    @objc public private(set) dynamic var typingIndicator: ContactEntity.TypingIndicator

    // MARK: - Public properties

    public let identity: ThreemaIdentity
    @objc(identity) public let objcIdentity: String
    
    let publicKey: Data
    
    public var isActive: Bool {
        state == .active
    }
    
    // If true when acquaintance level is group or deleted
    @objc public private(set) dynamic var isHidden: Bool

    // This only means it's a verified contact from the admin (in the same work package)
    // To check if this contact is a work ID, use the work identities list in user settings
    // bad naming because of the history...
    private(set) var isWorkContact: Bool

    public let showOtherTypeIcon: Bool
    
    /// This will return a attributed string from the displayName with invalid, inactive and blocked format
    public var attributedDisplayName: NSAttributedString {
        var attributedNameString = NSMutableAttributedString(string: displayName)
        
        // Check style for the title
        if state == .invalid {
            // Contact is invalid
            attributedNameString.addAttribute(
                .strikethroughStyle,
                value: 2,
                range: NSMakeRange(0, attributedNameString.length)
            )
            attributedNameString.addAttribute(
                .foregroundColor,
                value: UIColor.secondaryLabel,
                range: NSMakeRange(0, attributedNameString.length)
            )
        }
        else if state == .inactive {
            // Contact is inactive
            attributedNameString.addAttribute(
                .foregroundColor,
                value: UIColor.secondaryLabel,
                range: NSMakeRange(0, attributedNameString.length)
            )
        }
        else {
            attributedNameString.addAttribute(
                .foregroundColor,
                value: UIColor.label,
                range: NSMakeRange(0, attributedNameString.length)
            )
        }
        
        if UserSettings.shared().blacklist.contains(identity) {
            // Contact is blacklisted
            attributedNameString = NSMutableAttributedString(string: "🚫 " + attributedNameString.string)
        }
        
        return attributedNameString
    }
    
    /// Shorter version of `displayName` if available
    var shortDisplayName: String {
        // This is an "opt-in" feature
        guard !TargetManager.isBusinessApp else {
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
    
    public var isEchoEcho: Bool {
        identity.string == "ECHOECHO"
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
    
    public var supportsCalls: Bool {
        FeatureMask.check(contact: self, for: .o2OAudioCallSupport) &&
            !hasGatewayID &&
            !isEchoEcho
    }

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
        self.csi = contactEntity.csi
        self.jobTitle = contactEntity.jobTitle
        self.department = contactEntity.department
        self.verificationLevel = contactEntity.contactVerificationLevel
        self.state = contactEntity.contactState
        self.isHidden = contactEntity.isHidden
        self.isWorkContact = contactEntity.isWorkContact
        self.showOtherTypeIcon = contactEntity.showOtherThreemaTypeIcon
        self.isForwardSecurityAvailable = contactEntity.isForwardSecurityAvailable
        self.featureMask = Int(truncating: contactEntity.featureMask)
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
                if csi != contactEntity.csi {
                    csi = contactEntity.csi
                }
                if jobTitle != contactEntity.jobTitle {
                    jobTitle = contactEntity.jobTitle
                }
                if department != contactEntity.department {
                    department = contactEntity.department
                }
                if verificationLevel != contactEntity.contactVerificationLevel {
                    verificationLevel = contactEntity.contactVerificationLevel
                }
                let newState = contactEntity.contactState
                if state != newState {
                    state = newState
                }
                if isHidden != contactEntity.isHidden {
                    isHidden = contactEntity.isHidden
                }
                if isWorkContact != contactEntity.isWorkContact {
                    isWorkContact = contactEntity.isWorkContact
                }
                if featureMask != Int(truncating: contactEntity.featureMask) {
                    featureMask = Int(truncating: contactEntity.featureMask)
                    isForwardSecurityAvailable = contactEntity.isForwardSecurityAvailable
                }
                if isWorkContact != contactEntity.isWorkContact {
                    isWorkContact = contactEntity.isWorkContact
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
        case .inactive:
            value = "\(value) (\(Contact.inactiveString))"
        case .invalid:
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

    @objc public var verificationLevelImageSmall: UIImage {
        switch verificationLevel {
        case .unverified:
            StyleKit.verificationSmall0
        case .serverVerified:
            if isWorkContact {
                StyleKit.verificationSmall3
            }
            else {
                StyleKit.verificationSmall1
            }
        case .fullyVerified:
            if isWorkContact {
                StyleKit.verificationSmall4
            }
            else {
                StyleKit.verificationSmall2
            }
        }
    }

    public var verificationLevelImage: UIImage {
        switch verificationLevel {
        case .unverified:
            StyleKit.verification0
        case .serverVerified:
            if isWorkContact {
                StyleKit.verification3
            }
            else {
                StyleKit.verification1
            }
        case .fullyVerified:
            if isWorkContact {
                StyleKit.verification4
            }
            else {
                StyleKit.verification2
            }
        }
    }

    public var verificationLevelImageBig: UIImage {
        switch verificationLevel {
        case .unverified:
            StyleKit.verificationBig0
        case .serverVerified:
            if isWorkContact {
                StyleKit.verificationBig3
            }
            else {
                StyleKit.verificationBig1
            }
        case .fullyVerified:
            if isWorkContact {
                StyleKit.verificationBig4
            }
            else {
                StyleKit.verificationBig2
            }
        }
    }

    /// Localized string of verification level usable for accessibility
    @objc public var verificationLevelAccessibilityLabel: String {
        switch verificationLevel {
        case .unverified:
            Contact.workAdjustedVerificationLevelString0
        case .serverVerified:
            if isWorkContact {
                Contact.workAdjustedVerificationLevelString3
            }
            else {
                Contact.workAdjustedVerificationLevelString1
            }
        case .fullyVerified:
            if isWorkContact {
                Contact.workAdjustedVerificationLevelString4
            }
            else {
                Contact.workAdjustedVerificationLevelString2
            }
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
            csi == object.csi &&
            jobTitle == object.jobTitle &&
            department == object.department &&
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
