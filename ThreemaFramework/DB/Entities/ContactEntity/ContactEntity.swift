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
import CoreData
import Foundation

@objc(ContactEntity)
public final class ContactEntity: TMAManagedObject {
   
    // MARK: Enums

    @objc(ContactImportStatus) public enum ImportStatus: Int {
        case initial = 0, imported, custom
    }

    @objc public enum ContactState: Int {
        case active = 0, inactive, invalid
    }

    @objc(ContactVerificationLevel) public enum VerificationLevel: Int {
        case unverified = 0, serverVerified, fullyVerified
    }

    @objc public enum ReadReceipt: Int {
        case `default` = 0, send, doNotSend
    }

    @objc public enum TypingIndicator: Int {
        case `default` = 0, send, doNotSend
    }
    
    // MARK: Attributes

    // swiftformat:disable:next acronyms
    @NSManaged public var cnContactId: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var csi: String?
    @NSManaged public var department: String?
    
    /// Current feature mask fetched for this contact
    ///
    /// Always set this when the feature masked is fetched, even if it didn't change. The CD property will not be update
    /// if there was no change.
    /// However, this will do some cleanup if FS is not supported with the set mask.
    @NSManaged public private(set) var featureMask: NSNumber
    @NSManaged public private(set) var firstName: String?
    
    /// Set or Get the forward security state of this contact. Note that these states are only maintained for contacts
    /// with a DH session of version 1.0.
    /// TODO(ANDR-2452): Remove the forward security state when most of clients support 1.1 anyway
    @NSManaged public var forwardSecurityState: NSNumber
    @NSManaged private var hidden: NSNumber?
    @NSManaged public private(set) var identity: String
    
    /// Image data set from Contact of iOS
    @NSManaged public var imageData: Data?
    @NSManaged private var importStatus: NSNumber?
    @NSManaged public var jobTitle: String?
    @NSManaged public private(set) var lastName: String?
    @NSManaged public var profilePictureBlobID: String?
    @NSManaged private var profilePictureSended: NSNumber?
    @NSManaged public var profilePictureUpload: Date?
    @NSManaged private var property1: String?
    @NSManaged private var property2: NSNumber?
    @NSManaged public var publicKey: Data
    @NSManaged public var publicNickname: String?
    @NSManaged private var readReceipts: NSNumber
    @NSManaged public var sortIndex: NSNumber?
    @NSManaged public var sortInitial: String?
    @NSManaged private var state: NSNumber?
    @NSManaged private var typingIndicators: NSNumber
    @NSManaged private var verificationLevel: NSNumber
    @NSManaged public var verifiedEmail: String?
    @NSManaged public var verifiedMobileNo: String?
    
    /// This only means it's a verified contact from the admin (in the same work package). To check if this contact is a
    /// work ID, use the work identities list in user settings bad naming because of the history…
    @NSManaged public var workContact: NSNumber?
    
    // MARK: Custom getter/setter
    
    @objc dynamic var contactImportStatus: ImportStatus {
        get {
            ImportStatus(rawValue: importStatus?.intValue ?? ImportStatus.initial.rawValue) ?? .initial
        }
        
        set {
            willChangeValue(for: \.importStatus)
            setPrimitiveValue(NSNumber(integerLiteral: newValue.rawValue), forKey: "importStatus")
            didChangeValue(for: \.importStatus)
        }
    }
    
    @objc public dynamic var contactState: ContactState {
        get {
            ContactState(rawValue: state?.intValue ?? ContactState.inactive.rawValue) ?? .inactive
        }
        
        set {
            willChangeValue(for: \.state)
            setPrimitiveValue(NSNumber(integerLiteral: newValue.rawValue), forKey: "state")
            didChangeValue(for: \.state)
        }
    }
    
    @objc public dynamic var isHidden: Bool {
        get {
            hidden?.boolValue ?? false
        }
        
        set {
            willChangeValue(for: \.hidden)
            setPrimitiveValue(NSNumber(booleanLiteral: newValue), forKey: "hidden")
            didChangeValue(for: \.hidden)
        }
    }
    
    @objc dynamic var profilePictureSent: Bool {
        get {
            profilePictureSended?.boolValue ?? false
        }
        
        set {
            willChangeValue(for: \.profilePictureSended)
            setPrimitiveValue(NSNumber(booleanLiteral: newValue), forKey: "profilePictureSended")
            didChangeValue(for: \.profilePictureSended)
        }
    }
    
    @objc public dynamic var contactVerificationLevel: VerificationLevel {
        get {
            VerificationLevel(rawValue: verificationLevel.intValue) ?? .unverified
        }
        
        set {
            willChangeValue(for: \.verificationLevel)
            setPrimitiveValue(NSNumber(integerLiteral: newValue.rawValue), forKey: "verificationLevel")
            didChangeValue(for: \.verificationLevel)
        }
    }
    
    @objc public dynamic var readReceipt: ReadReceipt {
        get {
            ReadReceipt(rawValue: readReceipts.intValue) ?? .default
        }
        
        set {
            willChangeValue(for: \.readReceipts)
            setPrimitiveValue(NSNumber(integerLiteral: newValue.rawValue), forKey: "readReceipts")
            didChangeValue(for: \.readReceipts)
        }
    }
    
    @objc public dynamic var typingIndicator: TypingIndicator {
        get {
            TypingIndicator(rawValue: typingIndicators.intValue) ?? .default
        }
    
        set {
            willChangeValue(for: \.typingIndicators)
            setPrimitiveValue(NSNumber(integerLiteral: newValue.rawValue), forKey: "typingIndicators")
            didChangeValue(for: \.typingIndicators)
        }
    }
    
    // MARK: Relationships

    /// Image Data received by Threema contact
    @NSManaged public var contactImage: ImageDataEntity?
    @NSManaged public var conversations: Set<ConversationEntity>?
    @NSManaged public var groupConversations: Set<ConversationEntity>?
    @NSManaged public var reactions: Set<MessageReactionEntity>?
    
    /// All (group) messages that where rejected by this contact
    ///
    /// The inverse is `rejectedBy` of `BaseMessage`.
    @NSManaged public var rejectedMessages: Set<BaseMessageEntity>?
    
    // MARK: KVO

    // See: https://nshipster.com/key-value-observing/#automatic-property-notifications
    @objc public class var keyPathsForValuesAffectingDisplayName: Set<String> {
        [
            #keyPath(firstName),
            #keyPath(lastName),
            #keyPath(publicNickname),
            #keyPath(identity),
        ]
    }
    
    /// This calls KVO observers of `typingIndicator` if any of the provided key paths are called
    @objc public class var keyPathsForValuesAffectingTypingIndicator: Set<String> {
        [#keyPath(typingIndicators)]
    }
    
    /// This calls KVO observers of `readReceipt` if any of the provided key paths are called
    @objc public class var keyPathsForValuesAffectingReadReceipt: Set<String> {
        [#keyPath(readReceipts)]
    }
    
    // MARK: Lifecycle
    
    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: NSManagedObjectContext to insert created entity into
    ///   - cnContactID: CNContactID of the entity
    ///   - createdAt: `Date` entity was created at
    ///   - csi: CSI
    ///   - department: Departement
    ///   - featureMask: Feature mask value of the entity
    ///   - firstName: First name
    ///   - forwardSecurityState: Current forward security state
    ///   - hidden: `True` if contact is hidden
    ///   - identity: Threema ID
    ///   - imageData: `Data` fo the profile picture
    ///   - importStatus: Current import status of the contact
    ///   - jobTitle: Job title
    ///   - lastName: Last name
    ///   - profilePictureBlobID: BlobID of the profile picture
    ///   - profilePictureSended: If the profile picture was sent to the entity
    ///   - profilePictureUpload: When the profile picture was uploaded
    ///   - publicKey: Publickey of the contact
    ///   - publicNickname: Nickname
    ///   - readReceipts: If we send readreceipts to the contact
    ///   - sortIndex: Sort index of the entity in lists
    ///   - sortInitial: Initial the sortindex should be built upon
    ///   - state: Current state of the contact
    ///   - typingIndicators: If we send typing indicators to this contact
    ///   - verificationLevel: The current verification level
    ///   - verifiedEmail: The email of the contact
    ///   - verifiedMobileNo: The mobile nr of the contact
    ///   - workContact: If this contact is a verified work contact
    ///   - contactImage: The image of the contact
    ///   - conversations: Set of `ConversationEntity` of this contact
    ///   - groupConversations: Set of `ConversationEntity` of groups the contact is member in
    ///   - reactions: Set of `MessageReactionEntity` the contact has sent of
    ///   - rejectedMessages: Set of `BaseMessageEntity` the contact has rejected
    init(
        context: NSManagedObjectContext,
        cnContactID: String? = nil,
        createdAt: Date? = nil,
        csi: String? = nil,
        department: String? = nil,
        featureMask: Int,
        firstName: String? = nil,
        forwardSecurityState: NSNumber,
        hidden: NSNumber? = nil,
        identity: String,
        imageData: Data? = nil,
        importStatus: NSNumber? = nil,
        jobTitle: String? = nil,
        lastName: String? = nil,
        profilePictureBlobID: String? = nil,
        profilePictureSended: NSNumber? = nil,
        profilePictureUpload: Date? = nil,
        publicKey: Data,
        publicNickname: String? = nil,
        readReceipts: NSNumber,
        sortIndex: NSNumber? = nil,
        sortInitial: String? = nil,
        state: NSNumber? = nil,
        typingIndicators: NSNumber,
        verificationLevel: NSNumber,
        verifiedEmail: String? = nil,
        verifiedMobileNo: String? = nil,
        workContact: NSNumber? = nil,
        contactImage: ImageDataEntity? = nil,
        conversations: Set<ConversationEntity>? = nil,
        groupConversations: Set<ConversationEntity>? = nil,
        reactions: Set<MessageReactionEntity>? = nil,
        rejectedMessages: Set<BaseMessageEntity>? = nil
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "Contact", in: context)!
        super.init(entity: entity, insertInto: context)
        
        // swiftformat:disable:next acronyms
        self.cnContactId = cnContactID
        self.createdAt = createdAt
        self.csi = csi
        self.department = department
        self.featureMask = featureMask as NSNumber
        self.firstName = firstName
        self.forwardSecurityState = forwardSecurityState
        self.hidden = hidden
        self.identity = identity
        self.imageData = imageData
        self.importStatus = importStatus
        self.jobTitle = jobTitle
        self.lastName = lastName
        self.profilePictureBlobID = profilePictureBlobID
        self.profilePictureSended = profilePictureSended
        self.profilePictureUpload = profilePictureUpload
        self.publicKey = publicKey
        self.publicNickname = publicNickname
        self.readReceipts = readReceipts
        self.sortIndex = sortIndex
        self.sortInitial = sortInitial
        self.state = state
        self.typingIndicators = typingIndicators
        self.verificationLevel = verificationLevel
        self.verifiedEmail = verifiedEmail
        self.verifiedMobileNo = verifiedMobileNo
        self.workContact = workContact
        
        self.contactImage = contactImage
        self.conversations = conversations
        self.groupConversations = groupConversations
        self.reactions = reactions
        self.rejectedMessages = rejectedMessages
        
        updateSortInitial()
    }
    
    @objc override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
    
    @available(*, unavailable)
    public init() {
        fatalError("\(#function) not implemented")
    }
    
    @available(*, unavailable)
    public convenience init(context: NSManagedObjectContext) {
        fatalError("\(#function) not implemented")
    }
    
    // MARK: Custom Setter

    @objc public func setFeatureMask(to mask: Int) {
        // TODO: (IOS-5233) This will probably not work anymore if this is moved into a separate package
        // If the new feature mask doesn't support FS anymore terminate all sessions with this contact (& post system
        // message if needed).
        // This prevents that old sessions get never deleted if a contact stops supporting FS, but a terminate is never
        // received.
        // This also prevents a race conditions where we try to establish a session with a contact that doesn't support
        // FS
        // anymore, but the feature mask wasn't locally updated in the meantime. This new session might not be rejected
        // or
        // terminated, because only `Encapsulated` (i.e. data) FS messages are rejected when FS is disabled.
        if !isForwardSecurityAvailable {
            // Check if we actually used a FS session with this contact. If not we still terminate all sessions, but
            // won't
            // post a system message
            let bi = BusinessInjector()
            let fsContact = ForwardSecurityContact(identity: identity, publicKey: publicKey)
            let hasUsedForwardSecurity = bi.fsmp.hasContactUsedForwardSecurity(contact: fsContact)
            
            // Terminate sessions
            // If the contact really disabled FS it won't process the terminate, but we send it anyway just to be sure
            do {
                let deletedAnySession = try ForwardSecuritySessionTerminator().terminateAllSessions(
                    with: self,
                    cause: .disabledByRemote
                )
                
                // Post system message
                if hasUsedForwardSecurity, deletedAnySession, conversations?.count ?? 0 > 0 {
                    let em = EntityManager()
                    em.performAndWaitSave {
                        guard let conversation = em.entityFetcher.conversation(for: self) else {
                            return
                        }
                        let sysMessage = em.entityCreator.systemMessageEntity(for: conversation)
                        sysMessage?.type = kSystemMessageFsNotSupportedAnymore as NSNumber
                        sysMessage?.remoteSentDate = .now
                        if sysMessage?.isAllowedAsLastMessage ?? false {
                            conversation.lastMessage = sysMessage
                        }
                    }
                }
            }
            catch {
                DDLogError("Failed to terminate sessions on downgraded feature mask: \(error)")
            }
            // We will continue even if termination hasn't completed...
        }
        
        // Only update feature mask if actually changed. This prevents that the CD-entity is updated even though the
        // value
        // didn't change.
        
        guard featureMask.intValue != mask else {
            return
        }
        
        willChangeValue(for: \.featureMask)
        setPrimitiveValue(NSNumber(value: mask), forKey: "featureMask")
        didChangeValue(for: \.featureMask)
    }
    
    @objc public func setFirstName(to name: String?) {
        willChangeValue(for: \.firstName)
        setPrimitiveValue(name, forKey: "firstName")
        updateSortInitial()
        didChangeValue(for: \.firstName)
    }
    
    @objc public func setLastName(to name: String?) {
        willChangeValue(for: \.lastName)
        setPrimitiveValue(name, forKey: "lastName")
        updateSortInitial()
        didChangeValue(for: \.lastName)
    }
    
    @objc public func setIdentity(to id: String?) {
        willChangeValue(for: \.identity)
        setPrimitiveValue(id, forKey: "identity")
        updateSortInitial()
        didChangeValue(for: \.lastName)
    }
    
    @available(*, deprecated, message: "Only use for migration!")
    @objc public func getVerificationLevelForMigration() -> NSNumber {
        verificationLevel
    }
    
    // MARK: Generated accessors for groupConversations

    @objc(addConversationsObject:)
    @NSManaged public func addToConversations(_ value: ConversationEntity)

    @objc(removeConversationsObject:)
    @NSManaged public func removeFromConversations(_ value: ConversationEntity)

    @objc(addConversations:)
    @NSManaged public func addToConversations(_ values: NSSet)

    @objc(removeConversations:)
    @NSManaged public func removeFromConversations(_ values: NSSet)
    
    // MARK: Generated accessors for reactions

    @objc(addReactionsObject:)
    @NSManaged public func addToReactions(_ value: MessageReactionEntity)

    @objc(removeReactionsObject:)
    @NSManaged public func removeFromReactions(_ value: MessageReactionEntity)

    @objc(addReactions:)
    @NSManaged public func addToReactions(_ values: NSSet)

    @objc(removeReactions:)
    @NSManaged public func removeFromReactions(_ values: NSSet)

    // MARK: Generated accessors for rejectedMessages

    @objc(addRejectedMessagesObject:)
    @NSManaged public func addToRejectedMessages(_ value: BaseMessageEntity)

    @objc(removeRejectedMessagesObject:)
    @NSManaged public func removeFromRejectedMessages(_ value: BaseMessageEntity)

    @objc(addRejectedMessages:)
    @NSManaged public func addToRejectedMessages(_ values: NSSet)

    @objc(removeRejectedMessages:)
    @NSManaged public func removeFromRejectedMessages(_ values: NSSet)
}
