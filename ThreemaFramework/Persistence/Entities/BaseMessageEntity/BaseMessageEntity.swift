import CoreData
import Foundation
import ThreemaMacros

@objc(BaseMessageEntity)
public class BaseMessageEntity: ThreemaManagedObject {
    
    struct BaseMessageFlags: OptionSet {
        let rawValue: Int
        static let sendPush = 1 << 0
        static let dontQueue = 1 << 1
        static let dontAck = 1 << 2
        static let alreadyDelivered = 1 << 3
        static let group = 1 << 4
        static let immediateDelivery = 1 << 5
        static let silentPush = 1 << 6
        static let noDeliveryReceipt = 1 << 7
    }

    public enum ForwardSecurityMode: Int {
        /// No FS applied
        ///
        /// Incoming: Message received without FS
        ///
        /// Outgoing:
        ///  - 1:1: Not sent or sent without FS
        ///  - Group: Not sent. Otherwise this should be set to any of the `.outgoingGroupXY` cases.
        case forwardSecurityModeNone = 0

        /// Sent or received with 2DH
        ///
        /// This can only apply to 1:1 messages
        case forwardSecurityModeTwoDH = 1

        /// Sent or received with 4DH
        ///
        /// This can apply to 1:1 or _incoming_ group messages
        case forwardSecurityModeFourDH = 2

        /// Sent group message with no FS
        ///
        /// None of the receivers got the message with FS (i.e. none has a FS >= 1.2 session with this contact).
        /// This can only apply to outgoing group messages.
        case forwardSecurityModeOutgoingGroupNone = 3

        /// Sent group message partially with FS
        ///
        /// Some of the receivers got the message with FS (i.e. some have a FS >= 1.2 session with this contact).
        /// This can only apply to outgoing group messages.
        case forwardSecurityModeOutgoingGroupPartial = 4

        /// Sent group message fully with FS
        ///
        /// All of the receivers got the message with FS (i.e. all have a FS >= 1.2 session with this contact).
        /// This can only apply to outgoing group messages.
        case forwardSecurityModeOutgoingGroupFull = 5
    }
    
    public enum Field: String {
        case conversation
        case date
        case deletedAt
        case isOwn
        case read
        case rejectedBy
        case remoteSentDate
        
        public static func name(for field: Field, encrypted: Bool) -> String {
            switch field {
            case .conversation, .date, .isOwn, .read, .rejectedBy, .remoteSentDate:
                field.rawValue
            case .deletedAt:
                encrypted ? encryptedDeletedAtName : deletedAtName
            }
        }
    }

    // MARK: Attributes

    /// Creation date of this message in Core Data, non-optional in DB Model
    @NSManaged public var date: Date?

    @EncryptedField
    @objc public dynamic var deletedAt: Date? {
        get {
            getDeletedAt()
        }
        
        set {
            setDeletedAt(newValue)
        }
    }
    
    @EncryptedField
    @objc public dynamic var delivered: NSNumber {
        get {
            getDelivered()
        }
        
        set {
            setDelivered(newValue)
        }
    }
    
    /// Outgoing message:
    /// - Displayed as delivered
    /// - Update -> CSP: Sent (created) date set by sender (incoming `DeliveryReceiptMessage.date`), MDP: Created date
    /// set by sender (`D2d_IncomingMessage.createdAt`)
    /// Incoming message:
    /// - Displayed as received
    /// - Update -> CSP: Date set by receiver (`Date.now`), MDP: Reflected date set by receiver after reflecting
    /// (leader) or when processing incoming reflected message (none leader)
    @EncryptedField
    @objc public dynamic var deliveryDate: Date? {
        get {
            getDeliveryDate()
        }
        
        set {
            setDeliveryDate(newValue)
        }
    }
    
    @EncryptedField
    @objc public dynamic var flags: NSNumber? {
        get {
            getFlags()
        }
        
        set {
            setFlags(newValue)
        }
    }
    
    @EncryptedField
    @objc public dynamic var forwardSecurityMode: NSNumber {
        get {
            getForwardSecurityMode()
        }
        
        set {
            setForwardSecurityMode(newValue)
        }
    }
    
    @EncryptedField
    @objc public dynamic var groupDeliveryReceipts: [GroupDeliveryReceipt]? {
        get {
            getGroupDeliveryReceipts()
        }
        
        set {
            setGroupDeliveryReceipts(newValue)
        }
    }
    
    @NSManaged public var id: Data
    
    @EncryptedField
    @objc public dynamic var isCreatedFromWeb: NSNumber? {
        get {
            getIsCreatedFromWeb()
        }
        
        set {
            setIsCreatedFromWeb(newValue)
        }
    }
    
    /// Is this a message I sent?
    @NSManaged public var isOwn: NSNumber
    
    @EncryptedField
    @objc public dynamic var lastEditedAt: Date? {
        get {
            getLastEditedAt()
        }
        
        set {
            setLastEditedAt(newValue)
        }
    }
    
    @NSManaged public var read: NSNumber
    @NSManaged public var readDate: Date?
   
    /// Remote sent date of message. This can be `nil` and these must be handled by the caller.
    /// Before we rewrote this class in Swift, this was never `nil`.
    ///
    /// Outgoing message:
    /// - Displayed as sent
    /// - Update -> CSP: Staring with with 4.9 date when message was acknowledged by server. For local messages and
    /// before 4.7 `date` is returned. MDP: Reflected date after reflecting
    /// Incoming message:
    /// - Displayed as sent
    /// - Update -> CSP: Sent (created) date set by sender (`AbstractMessage.date`), MDP: Created date set by sender
    /// (`D2d_IncomingMessage.createdAt`)
    @NSManaged public var remoteSentDate: Date?
    
    /// Set if sending failed (this includes rejected by FS)
    @EncryptedField
    @objc public dynamic var sendFailed: NSNumber? {
        get {
            getSendFailed()
        }
        
        set {
            setSendFailed(newValue)
        }
    }
    
    @EncryptedField
    @objc public dynamic var sent: NSNumber {
        get {
            getSent()
        }
        
        set {
            setSent(newValue)
        }
    }
    
    @available(*, deprecated, message: "Ack/Dec have been migrated to `reactions` in Version 6.0. Do not use.")
    @EncryptedField
    @objc public dynamic var userack: NSNumber {
        get {
            getUserAck()
        }
        
        set {
            setUserAck(newValue)
        }
    }
    
    @available(*, deprecated, message: "Ack/Dec have been migrated to `reactions` in Version 6.0. Do not use.")
    @EncryptedField
    @objc public dynamic var userackDate: Date? {
        get {
            getUserAckDate()
        }
        
        set {
            setUserAckDate(newValue)
        }
    }
   
    @EncryptedField(name: "webRequestId")
    // swiftformat:disable:next acronyms
    @objc(webRequestId) public dynamic var webRequestID: String? {
        get {
            getWebRequestID()
        }
        
        set {
            setWebRequestID(newValue)
        }
    }
    
    // MARK: Relationships

    @NSManaged public var conversation: ConversationEntity
    @NSManaged public var distributedMessages: Set<BaseMessageEntity>?
    @NSManaged public var distributionListMessage: BaseMessageEntity?
    @NSManaged public var historyEntries: Set<MessageHistoryEntryEntity>?
    @NSManaged public var messageMarkers: MessageMarkersEntity?
    @NSManaged public var reactions: Set<MessageReactionEntity>?
    
    /// Contacts that rejected this message
    ///
    /// This is only set for group messages.
    /// The inverse is `rejectedMessages` in `ContactEntity`.
    @NSManaged public var rejectedBy: Set<ContactEntity>?
    @NSManaged public var sender: ContactEntity?
    
    // MARK: Private properties

    // Cached decrypted values
    private var decryptedDeletedAt: Date?
    private var decryptedDelivered: Bool? // Non optional
    private var decryptedDeliveryDate: Date?
    private var decryptedFlags: Int32?
    private var decryptedForwardSecurityMode: Int16? // Non optional
    private var decryptedGroupDeliveryReceipts: [GroupDeliveryReceipt]?
    private var decryptedIsCreatedFromWeb: Bool?
    private var decryptedLastEditedAt: Date?
    private var decryptedSendFailed: Bool?
    private var decryptedSent: Bool? // Non optional
    private var decryptedUserack: Bool? // Non optional
    private var decryptedUserackDate: Date?
    private var decryptedWebRequestID: String?

    // MARK: - Lifecycle

    /// Initializer that ensures all non-optional values are set (don't us this directly)
    ///
    /// - Warning: This should only be called from children (Abstract entities should never be instantiated:
    /// https://fatbobman.com/en/posts/model-inheritance-in-core-data/#abstract-entity)
    ///
    /// - Parameters:
    ///   - entity: Description of entity to create
    ///   - context: Context to insert new entity into
    ///   - date: Date the message was created in Core Data (should normally be `.now`)
    ///   - deletedAt: `Date` the message was deleted
    ///   - delivered: `True` if message was delivered
    ///   - deliveryDate: `Date` the message was delivered
    ///   - flags: Flags of the message
    ///   - forwardSecurityMode: Forward security mode of the message
    ///   - groupDeliveryReceipts: `GroupDeliveryReceipt` of the message
    ///   - id: ID of the Message
    ///   - isCreatedFromWeb: `True` if message was created in Web
    ///   - isOwn: `True` if message is own
    ///   - lastEditedAt: `Date` the message was last edited at
    ///   - read: `True` if message was read
    ///   - readDate: `Date` the message was read
    ///   - remoteSentDate: `Date` the message sent
    ///   - sendFailed: `True` if message sending failed
    ///   - sent: `True` if message has been sent
    ///   - webRequestID: ID of the web request of the message
    ///   - conversation: `ConversationEntity` the message belongs to
    ///   - distributedMessages: Set of `BaseMessageEntity`s that were distributed to other chats
    ///   - distributionListMessage: `BaseMessageEntity` from where this message was distributed from
    ///   - historyEntries: Set of `MessageHistoryEntryEntity` that contain the edit history
    ///   - messageMarkers: `MessageMarkersEntity` containing the markers applied to this message
    ///   - reactions: Set of `MessageReactionEntity` that contains the reactions applied to this message
    ///   - rejectedBy: Set of `ContactEntity` that contains contacts that have rejected this message
    ///   - sender: `ContactEntity` that sent this message
    init(
        entity: NSEntityDescription,
        insertInto context: NSManagedObjectContext?,
        date: Date = .now,
        deletedAt: Date? = nil,
        delivered: Bool = false,
        deliveryDate: Date? = nil,
        flags: NSNumber? = nil,
        forwardSecurityMode: Int = 0,
        groupDeliveryReceipts: [GroupDeliveryReceipt]? = nil,
        id: Data,
        isCreatedFromWeb: Bool = false,
        isOwn: Bool,
        lastEditedAt: Date? = nil,
        read: Bool = false,
        readDate: Date? = nil,
        remoteSentDate: Date? = nil,
        sendFailed: Bool? = nil,
        sent: Bool = false,
        webRequestID: String? = nil,
        conversation: ConversationEntity,
        distributedMessages: Set<BaseMessageEntity>? = nil,
        distributionListMessage: BaseMessageEntity? = nil,
        historyEntries: Set<MessageHistoryEntryEntity>? = nil,
        messageMarkers: MessageMarkersEntity? = nil,
        reactions: Set<MessageReactionEntity>? = nil,
        rejectedBy: Set<ContactEntity>? = nil,
        sender: ContactEntity? = nil,
    ) {
        super.init(entity: entity, insertInto: context)
        
        self.date = date
        setDeletedAt(deletedAt)
        setDelivered(delivered as NSNumber)
        setDeliveryDate(deliveryDate)
        setFlags(flags)
        setForwardSecurityMode(forwardSecurityMode as NSNumber)
        setGroupDeliveryReceipts(groupDeliveryReceipts)
        self.id = id
        setIsCreatedFromWeb(isCreatedFromWeb as NSNumber)
        self.isOwn = isOwn as NSNumber
        setLastEditedAt(lastEditedAt)
        self.read = read as NSNumber
        self.readDate = readDate
        self.remoteSentDate = remoteSentDate
        
        if let sendFailed {
            setSendFailed(sendFailed as NSNumber)
        }
        
        setSent(sent as NSNumber)
        
        // Deprecated
        setUserAck(NSNumber(booleanLiteral: false))
        setUserAckDate(nil)
        
        setWebRequestID(webRequestID)
        
        self.conversation = conversation
        self.distributedMessages = distributedMessages
        self.distributionListMessage = distributionListMessage
        self.historyEntries = historyEntries
        self.messageMarkers = messageMarkers
        self.reactions = reactions
        self.rejectedBy = rejectedBy
        self.sender = sender
    }
    
    override private init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
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

    // MARK: DeletedAt
    
    private func getDeletedAt() -> Date? {
        var value: Date?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedDeletedAt, forKey: Self.encryptedDeletedAtName)
            value = decryptedDeletedAt
        }
        else {
            willAccessValue(forKey: Self.deletedAtName)
            value = primitiveValue(forKey: Self.deletedAtName) as? Date
            didAccessValue(forKey: Self.deletedAtName)
        }
        return value
    }
    
    private func setDeletedAt(_ newValue: Date?) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedDeletedAtName)
            decryptedDeletedAt = newValue
        }
        else {
            willChangeValue(forKey: Self.deletedAtName)
            setPrimitiveValue(newValue, forKey: Self.deletedAtName)
            didChangeValue(forKey: Self.deletedAtName)
        }
    }
    
    // MARK: Delivered
    
    private func getDelivered() -> NSNumber {
        var value: NSNumber = 0 // Default value
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decrypt(&decryptedDelivered, forKey: Self.encryptedDeliveredName)
            if let decryptedDelivered {
                value = NSNumber(booleanLiteral: decryptedDelivered)
            }
        }
        else {
            willAccessValue(forKey: Self.deliveredName)
            value = primitiveValue(forKey: Self.deliveredName) as? NSNumber ?? value
            didAccessValue(forKey: Self.deliveredName)
        }
        return value
    }
    
    private func setDelivered(_ newValue: NSNumber) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encrypt(newValue.boolValue, forKey: Self.encryptedDeliveredName)
            decryptedDelivered = newValue.boolValue
        }
        else {
            willChangeValue(forKey: Self.deliveredName)
            setPrimitiveValue(newValue, forKey: Self.deliveredName)
            didChangeValue(forKey: Self.deliveredName)
        }
    }
    
    // MARK: DeliveryDate
    
    private func getDeliveryDate() -> Date? {
        var value: Date?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedDeliveryDate, forKey: Self.encryptedDeliveryDateName)
            value = decryptedDeliveryDate
        }
        else {
            willAccessValue(forKey: Self.deliveryDateName)
            value = primitiveValue(forKey: Self.deliveryDateName) as? Date
            didAccessValue(forKey: Self.deliveryDateName)
        }
        return value
    }
    
    private func setDeliveryDate(_ newValue: Date?) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedDeliveryDateName)
            decryptedDeliveryDate = newValue
        }
        else {
            willChangeValue(forKey: Self.deliveryDateName)
            setPrimitiveValue(newValue, forKey: Self.deliveryDateName)
            didChangeValue(forKey: Self.deliveryDateName)
        }
    }
    
    // MARK: Flags

    private func getFlags() -> NSNumber? {
        var value: NSNumber?
        guard let managedObjectContext else {
            return nil
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedFlags, forKey: Self.encryptedFlagsName)
            if let decryptedFlags {
                value = NSNumber(integerLiteral: Int(decryptedFlags))
            }
        }
        else {
            willAccessValue(forKey: Self.flagsName)
            value = primitiveValue(forKey: Self.flagsName) as? NSNumber
            didAccessValue(forKey: Self.flagsName)
        }
        return value
    }
    
    private func setFlags(_ newValue: NSNumber?) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue?.int32Value, forKey: Self.encryptedFlagsName)
            decryptedFlags = newValue?.int32Value
        }
        else {
            willChangeValue(forKey: Self.flagsName)
            setPrimitiveValue(newValue, forKey: Self.flagsName)
            didChangeValue(forKey: Self.flagsName)
        }
    }
    
    // MARK: ForwardSecurityMode
    
    private func getForwardSecurityMode() -> NSNumber {
        var value: NSNumber = 0 // Default value
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decrypt(&decryptedForwardSecurityMode, forKey: Self.encryptedForwardSecurityModeName)
            if let decryptedForwardSecurityMode {
                value = NSNumber(integerLiteral: Int(decryptedForwardSecurityMode))
            }
        }
        else {
            willAccessValue(forKey: Self.forwardSecurityModeName)
            value = primitiveValue(forKey: Self.forwardSecurityModeName) as? NSNumber ?? value
            didAccessValue(forKey: Self.forwardSecurityModeName)
        }
        return value
    }
    
    private func setForwardSecurityMode(_ newValue: NSNumber) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encrypt(newValue.int16Value, forKey: Self.encryptedForwardSecurityModeName)
            decryptedForwardSecurityMode = newValue.int16Value
        }
        else {
            willChangeValue(forKey: Self.forwardSecurityModeName)
            setPrimitiveValue(newValue, forKey: Self.forwardSecurityModeName)
            didChangeValue(forKey: Self.forwardSecurityModeName)
        }
    }
    
    // MARK: GroupDeliveryReceipts

    private func getGroupDeliveryReceipts() -> [GroupDeliveryReceipt]? {
        var value: [GroupDeliveryReceipt]?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(
                &decryptedGroupDeliveryReceipts,
                forKey: Self.encryptedGroupDeliveryReceiptsName
            )
            value = decryptedGroupDeliveryReceipts
        }
        else {
            willAccessValue(forKey: Self.groupDeliveryReceiptsName)
            value = primitiveValue(forKey: Self.groupDeliveryReceiptsName) as? [GroupDeliveryReceipt]
            didAccessValue(forKey: Self.groupDeliveryReceiptsName)
        }
        return value
    }
    
    private func setGroupDeliveryReceipts(_ newValue: [GroupDeliveryReceipt]?) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedGroupDeliveryReceiptsName)
            decryptedGroupDeliveryReceipts = newValue
        }
        else {
            willChangeValue(forKey: Self.groupDeliveryReceiptsName)
            setPrimitiveValue(newValue, forKey: Self.groupDeliveryReceiptsName)
            didChangeValue(forKey: Self.groupDeliveryReceiptsName)
        }
    }
    
    // MARK: IsCreatedFromWeb
    
    private func getIsCreatedFromWeb() -> NSNumber? {
        var value: NSNumber?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedIsCreatedFromWeb, forKey: Self.encryptedIsCreatedFromWebName)
            if let decryptedIsCreatedFromWeb {
                value = NSNumber(booleanLiteral: decryptedIsCreatedFromWeb)
            }
        }
        else {
            willAccessValue(forKey: Self.isCreatedFromWebName)
            value = primitiveValue(forKey: Self.isCreatedFromWebName) as? NSNumber
            didAccessValue(forKey: Self.isCreatedFromWebName)
        }
        return value
    }
    
    private func setIsCreatedFromWeb(_ newValue: NSNumber?) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue?.boolValue, forKey: Self.encryptedIsCreatedFromWebName)
            decryptedIsCreatedFromWeb = newValue?.boolValue
        }
        else {
            willChangeValue(forKey: Self.isCreatedFromWebName)
            setPrimitiveValue(newValue, forKey: Self.isCreatedFromWebName)
            didChangeValue(forKey: Self.isCreatedFromWebName)
        }
    }
    
    // MARK: LastEditedAt
    
    private func getLastEditedAt() -> Date? {
        var value: Date?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedLastEditedAt, forKey: Self.encryptedLastEditedAtName)
            value = decryptedLastEditedAt
        }
        else {
            willAccessValue(forKey: Self.lastEditedAtName)
            value = primitiveValue(forKey: Self.lastEditedAtName) as? Date
            didAccessValue(forKey: Self.lastEditedAtName)
        }
        return value
    }
    
    private func setLastEditedAt(_ newValue: Date?) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedLastEditedAtName)
            decryptedLastEditedAt = newValue
        }
        else {
            willChangeValue(forKey: Self.lastEditedAtName)
            setPrimitiveValue(newValue, forKey: Self.lastEditedAtName)
            didChangeValue(forKey: Self.lastEditedAtName)
        }
    }
    
    // MARK: SendFailed
    
    private func getSendFailed() -> NSNumber? {
        var value: NSNumber?
        guard let managedObjectContext else {
            return nil
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedSendFailed, forKey: Self.encryptedSendFailedName)
            if let decryptedSendFailed {
                value = NSNumber(booleanLiteral: decryptedSendFailed)
            }
        }
        else {
            willAccessValue(forKey: Self.sendFailedName)
            value = primitiveValue(forKey: Self.sendFailedName) as? NSNumber
            didAccessValue(forKey: Self.sendFailedName)
        }
        return value
    }
    
    private func setSendFailed(_ newValue: NSNumber?) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue?.boolValue, forKey: Self.encryptedSendFailedName)
            decryptedSendFailed = newValue?.boolValue
        }
        else {
            willChangeValue(forKey: Self.sendFailedName)
            setPrimitiveValue(newValue, forKey: Self.sendFailedName)
            didChangeValue(forKey: Self.sendFailedName)
        }
    }
    
    // MARK: Sent
    
    private func getSent() -> NSNumber {
        var value: NSNumber = 0 // Default value
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decrypt(&decryptedSent, forKey: Self.encryptedSentName)
            if let decryptedSent {
                value = NSNumber(booleanLiteral: decryptedSent)
            }
        }
        else {
            willAccessValue(forKey: Self.sentName)
            value = primitiveValue(forKey: Self.sentName) as? NSNumber ?? value
            didAccessValue(forKey: Self.sentName)
        }
        return value
    }
    
    private func setSent(_ newValue: NSNumber) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encrypt(newValue.boolValue, forKey: Self.encryptedSentName)
            decryptedSent = newValue.boolValue
        }
        else {
            willChangeValue(forKey: Self.sentName)
            setPrimitiveValue(newValue, forKey: Self.sentName)
            didChangeValue(forKey: Self.sentName)
        }
    }
    
    // MARK: Userack
    
    private func getUserAck() -> NSNumber {
        var value: NSNumber = 0 // Default value
        guard let managedObjectContext else {
            return 0
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decrypt(&decryptedUserack, forKey: Self.encryptedUserackName)
            if let decryptedUserack {
                value = NSNumber(booleanLiteral: decryptedUserack)
            }
        }
        else {
            willAccessValue(forKey: Self.userackName)
            value = primitiveValue(forKey: Self.userackName) as? NSNumber ?? value
            didAccessValue(forKey: Self.userackName)
        }
        return value
    }
    
    private func setUserAck(_ newValue: NSNumber) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encrypt(newValue.boolValue, forKey: Self.encryptedUserackName)
            decryptedUserack = newValue.boolValue
        }
        else {
            willChangeValue(forKey: Self.userackName)
            setPrimitiveValue(newValue, forKey: Self.userackName)
            didChangeValue(forKey: Self.userackName)
        }
    }
    
    // MARK: UserackDate
    
    private func getUserAckDate() -> Date? {
        var value: Date?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedUserackDate, forKey: Self.encryptedUserackDateName)
            value = decryptedUserackDate
        }
        else {
            willAccessValue(forKey: Self.userackDateName)
            value = primitiveValue(forKey: Self.userackDateName) as? Date
            didAccessValue(forKey: Self.userackDateName)
        }
        return value
    }
    
    private func setUserAckDate(_ newValue: Date?) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedUserackDateName)
            decryptedUserackDate = newValue
        }
        else {
            willChangeValue(forKey: Self.userackDateName)
            setPrimitiveValue(newValue, forKey: Self.userackDateName)
            didChangeValue(forKey: Self.userackDateName)
        }
    }
    
    // MARK: WebRequestID

    private func getWebRequestID() -> String? {
        var value: String?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedWebRequestID, forKey: Self.encryptedWebRequestIDName)
            value = decryptedWebRequestID
        }
        else {
            willAccessValue(forKey: Self.webRequestIDName)
            value = primitiveValue(forKey: Self.webRequestIDName) as? String
            didAccessValue(forKey: Self.webRequestIDName)
        }
        return value
    }
    
    private func setWebRequestID(_ newValue: String?) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedWebRequestIDName)
            decryptedWebRequestID = newValue
        }
        else {
            willChangeValue(forKey: Self.webRequestIDName)
            setPrimitiveValue(newValue, forKey: Self.webRequestIDName)
            didChangeValue(forKey: Self.webRequestIDName)
        }
    }

    // MARK: - Reset cached values

    override public func didChangeValue(forKey key: String) {
        if key == Self.encryptedDeletedAtName {
            decryptedDeletedAt = nil
        }
        else if key == Self.encryptedDeliveredName {
            decryptedDelivered = nil
        }
        else if key == Self.encryptedDeliveryDateName {
            decryptedDeliveryDate = nil
        }
        else if key == Self.encryptedFlagsName {
            decryptedFlags = nil
        }
        else if key == Self.encryptedForwardSecurityModeName {
            decryptedForwardSecurityMode = nil
        }
        else if key == Self.encryptedGroupDeliveryReceiptsName {
            decryptedGroupDeliveryReceipts = nil
        }
        else if key == Self.encryptedIsCreatedFromWebName {
            decryptedIsCreatedFromWeb = nil
        }
        else if key == Self.encryptedLastEditedAtName {
            decryptedLastEditedAt = nil
        }
        else if key == Self.encryptedSendFailedName {
            decryptedSendFailed = nil
        }
        else if key == Self.encryptedSentName {
            decryptedSent = nil
        }
        else if key == Self.encryptedUserackName {
            decryptedUserack = nil
        }
        else if key == Self.encryptedUserackDateName {
            decryptedUserackDate = nil
        }
        else if key == Self.encryptedWebRequestIDName {
            decryptedWebRequestID = nil
        }
        super.didChangeValue(forKey: key)
    }

    override public func didTurnIntoFault() {
        decryptedDeletedAt = nil
        decryptedDelivered = nil
        decryptedDeliveryDate = nil
        decryptedFlags = nil
        decryptedForwardSecurityMode = nil
        decryptedGroupDeliveryReceipts = nil
        decryptedIsCreatedFromWeb = nil
        decryptedLastEditedAt = nil
        decryptedSendFailed = nil
        decryptedSent = nil
        decryptedUserack = nil
        decryptedUserackDate = nil
        decryptedWebRequestID = nil
        super.didTurnIntoFault()
    }

    // MARK: Generated accessors for distributedMessages

    @objc(addDistributedMessagesObject:)
    @NSManaged public func addToDistributedMessages(_ value: BaseMessageEntity)

    @objc(removeDistributedMessagesObject:)
    @NSManaged public func removeFromDistributedMessages(_ value: BaseMessageEntity)

    @objc(addDistributedMessages:)
    @NSManaged public func addToDistributedMessages(_ values: NSSet)

    @objc(removeDistributedMessages:)
    @NSManaged public func removeFromDistributedMessages(_ values: NSSet)
    
    // MARK: Generated accessors for historyEntries

    @objc(addHistoryEntriesObject:)
    @NSManaged public func addToHistoryEntries(_ value: MessageHistoryEntryEntity)

    @objc(removeHistoryEntriesObject:)
    @NSManaged public func removeFromHistoryEntries(_ value: MessageHistoryEntryEntity)

    @objc(addHistoryEntries:)
    @NSManaged public func addToHistoryEntries(_ values: NSSet)

    @objc(removeHistoryEntries:)
    @NSManaged public func removeFromHistoryEntries(_ values: NSSet)
    
    // MARK: Generated accessors for reactions

    @objc(addReactionsObject:)
    @NSManaged public func addToReactions(_ value: MessageReactionEntity)

    @objc(removeReactionsObject:)
    @NSManaged public func removeFromReactions(_ value: MessageReactionEntity)

    @objc(addReactions:)
    @NSManaged public func addToReactions(_ values: NSSet)

    @objc(removeReactions:)
    @NSManaged public func removeFromReactions(_ values: NSSet)
    
    // MARK: Generated accessors for rejectedBy

    @objc(addRejectedByObject:)
    @NSManaged public func addToRejectedBy(_ value: ContactEntity)

    @objc(removeRejectedByObject:)
    @NSManaged public func removeFromRejectedBy(_ value: ContactEntity)

    @objc(addRejectedBy:)
    @NSManaged public func addToRejectedBy(_ values: NSSet)

    @objc(removeRejectedBy:)
    @NSManaged public func removeFromRejectedBy(_ values: NSSet)
}
