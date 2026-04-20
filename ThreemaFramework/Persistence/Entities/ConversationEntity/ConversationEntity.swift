import CoreData
import Foundation
import ThreemaMacros

@objc(ConversationEntity)
public final class ConversationEntity: ThreemaManagedObject, Identifiable {
    
    public enum Field: String {
        case category
        case groupName
        case groupImage
        case lastMessage
        case lastUpdate
        case members
        case unreadMessageCount
        case typing
        case visibility

        public static func name(for field: Field, encrypted: Bool) -> String {
            switch field {
            case .category, .groupImage, .lastMessage, .lastUpdate, .members, .unreadMessageCount, .typing, .visibility:
                field.rawValue
            case .groupName:
                encrypted ? encryptedGroupNameName : groupNameName
            }
        }
    }

    // MARK: Attributes

    @NSManaged public var category: NSNumber
    // swiftformat:disable:next acronyms
    @NSManaged @objc(groupId) public var groupID: Data?
    @NSManaged public var groupImageSetDate: Date?
    @NSManaged public var groupMyIdentity: String?

    @EncryptedField
    @objc public dynamic var groupName: String? {
        get {
            getGroupName()
        }
        
        set {
            setGroupName(newValue)
        }
    }
    
    @NSManaged public private(set) var lastTypingStart: Date?
    
    @NSManaged public var lastUpdate: Date?
   
    @available(*, deprecated, renamed: "visibility", message: "Use `.pinned` in `visibility` instead.")
    @EncryptedField
    @objc public dynamic var marked: NSNumber {
        get {
            getMarked()
        }
        
        set {
            setMarked(newValue)
        }
    }
    
    @objc public dynamic var typing: NSNumber {
        get {
            getTyping()
        }
        
        set {
            setTyping(newValue)
        }
    }
    
    @NSManaged public var unreadMessageCount: NSNumber
    @NSManaged public var visibility: NSNumber

    // MARK: Relationships

    @NSManaged public var ballots: Set<BallotEntity>?
    @NSManaged public var contact: ContactEntity?
    @NSManaged public var distributionList: DistributionListEntity?
    @NSManaged public var groupImage: ImageDataEntity?
    @NSManaged public var lastMessage: BaseMessageEntity?
    @NSManaged public var members: Set<ContactEntity>?

    // MARK: Private properties

    // Cached decrypted values
    private var decryptedGroupName: String?
    private var decryptedMarked: Bool? // Non optional

    // MARK: - Lifecycle

    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: `NSManagedObjectContext` to insert created entity into
    ///   - category: `Category` of the conversation
    ///   - groupID: GroupID of the conversation
    ///   - groupImageSetDate: `Date` the group image was set
    ///   - groupMyIdentity: Our ID when we were added to the group
    ///   - groupName: The name of the group
    ///   - lastTypingStart: `Date` we last received a start typing
    ///   - lastUpdate: `Date` the conversation was last updated at
    ///   - typing: `True` if the other side is typing at the moment
    ///   - unreadMessageCount: Count of unread messages
    ///   - visibility: `Visibility` of the conversation
    ///   - groupImage: `ImageDataEntity` of the group picture
    ///   - lastMessage: `BaseMessageEntity` that is the last message
    ///   - distributionList: `DistributionListEntity` if the conversation is a distribution list
    ///   - contact: `ContactEntity` other participant if conversation is 1:1
    ///   - members: Set of `ContactEntity` if conversation is a group
    init(
        context: NSManagedObjectContext,
        category: Category = .default,
        groupID: Data? = nil,
        groupImageSetDate: Date? = nil,
        groupMyIdentity: String? = nil,
        groupName: String? = nil,
        lastTypingStart: Date? = nil,
        lastUpdate: Date? = nil,
        typing: Bool = false,
        unreadMessageCount: NSNumber = 0,
        visibility: Visibility = .default,
        groupImage: ImageDataEntity? = nil,
        lastMessage: BaseMessageEntity? = nil,
        distributionList: DistributionListEntity? = nil,
        contact: ContactEntity? = nil,
        members: Set<ContactEntity>? = nil
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "Conversation", in: context)!
        super.init(entity: entity, insertInto: context)
        
        self.category = category.rawValue as NSNumber
        self.groupID = groupID
        self.groupImageSetDate = groupImageSetDate
        self.groupMyIdentity = groupMyIdentity
        setGroupName(groupName)
        self.lastTypingStart = lastTypingStart
        self.lastUpdate = lastUpdate
        // Deprecated
        setMarked(false)
        setTyping(NSNumber(booleanLiteral: typing))
        self.unreadMessageCount = unreadMessageCount
        self.visibility = visibility.rawValue as NSNumber
        
        self.groupImage = groupImage
        self.lastMessage = lastMessage
        self.ballots = ballots
        self.distributionList = distributionList
        self.contact = contact
        self.members = members
    }
    
    @objc override private init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
    
    @available(*, unavailable)
    init() {
        fatalError("\(#function) not implemented")
    }
    
    @available(*, unavailable)
    convenience init(context: NSManagedObjectContext) {
        fatalError("\(#function) not implemented")
    }
    
    // MARK: - Custom get/set functions
    
    // MARK: GroupName

    private func getGroupName() -> String? {
        var value: String?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedGroupName, forKey: Self.encryptedGroupNameName)
            value = decryptedGroupName
        }
        else {
            willAccessValue(forKey: Self.groupNameName)
            value = primitiveValue(forKey: Self.groupNameName) as? String
            didAccessValue(forKey: Self.groupNameName)
        }
        return value
    }
    
    private func setGroupName(_ newValue: String?) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedGroupNameName)
            decryptedGroupName = newValue
        }
        else {
            willChangeValue(forKey: Self.groupNameName)
            setPrimitiveValue(newValue, forKey: Self.groupNameName)
            didChangeValue(forKey: Self.groupNameName)
        }
    }
    
    // MARK: LastTypingStart
    
    // MARK: Marked
    
    private func getMarked() -> NSNumber {
        var value: NSNumber = 0 // Default value
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decrypt(&decryptedMarked, forKey: Self.encryptedMarkedName)
            if let decryptedMarked {
                value = NSNumber(booleanLiteral: decryptedMarked)
            }
        }
        else {
            willAccessValue(forKey: Self.markedName)
            value = primitiveValue(forKey: Self.markedName) as? NSNumber ?? value
            didAccessValue(forKey: Self.markedName)
        }
        return value
    }
    
    private func setMarked(_ newValue: NSNumber) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encrypt(newValue.boolValue, forKey: Self.encryptedMarkedName)
            decryptedMarked = newValue.boolValue
        }
        else {
            willChangeValue(forKey: Self.markedName)
            setPrimitiveValue(newValue, forKey: Self.markedName)
            didChangeValue(forKey: Self.markedName)
        }
    }
    
    // MARK: Typing
    
    private func getTyping() -> NSNumber {
        guard !willBeDeleted else {
            return NSNumber(booleanLiteral: false)
        }

        let typingName = Field.name(for: .typing, encrypted: false)
        var value: NSNumber = 0 // Default value
        willAccessValue(forKey: typingName)
        value = primitiveValue(forKey: typingName) as? NSNumber ?? value
        didAccessValue(forKey: typingName)
        return value
    }
    
    private func setTyping(_ newValue: NSNumber) {
        let typingName = Field.name(for: .typing, encrypted: false)
        willChangeValue(forKey: typingName)
        setPrimitiveValue(newValue, forKey: typingName)
        didChangeValue(forKey: typingName)

        if typing.boolValue {
            lastTypingStart = .now
        }
    }
    
    // MARK: - Reset cached values

    override public func didChangeValue(forKey key: String) {
        if key == Self.encryptedGroupNameName {
            decryptedGroupName = nil
        }
        else if key == Self.encryptedMarkedName {
            decryptedMarked = nil
        }
        super.didChangeValue(forKey: key)
    }

    override public func didTurnIntoFault() {
        decryptedGroupName = nil
        decryptedMarked = nil
        super.didTurnIntoFault()
    }

    // MARK: Generated accessors for ballots

    @objc(addBallotsObject:)
    @NSManaged public func addToBallots(_ value: BallotEntity)

    @objc(removeBallotsObject:)
    @NSManaged public func removeFromBallots(_ value: BallotEntity)

    @objc(addBallots:)
    @NSManaged public func addToBallots(_ values: NSSet)

    @objc(removeBallots:)
    @NSManaged public func removeFromBallots(_ values: NSSet)
    
    // MARK: Generated accessors for members

    @objc(addMembersObject:)
    @NSManaged public func addToMembers(_ value: ContactEntity)

    @objc(removeMembersObject:)
    @NSManaged public func removeFromMembers(_ value: ContactEntity)

    @objc(addMembers:)
    @NSManaged public func addToMembers(_ values: NSSet)

    @objc(removeMembers:)
    @NSManaged public func removeFromMembers(_ values: NSSet)
}
