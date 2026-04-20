import CocoaLumberjackSwift
import CoreData
import Foundation
import ThreemaMacros

@objc(ContactEntity)
public final class ContactEntity: ThreemaManagedObject {
    
    public enum Field: String {
        case featureMask
        case typing

        public static func name(for field: Field, encrypted: Bool) -> String {
            switch field {
            case featureMask:
                encrypted ? encryptedFeatureMaskName : featureMaskName
            case .typing:
                field.rawValue
            }
        }
    }
    
    // MARK: Enums
    
    @objc(ContactImportStatus) public enum ImportStatus: Int {
        case initial = 0, imported, custom
    }
    
    @objc public enum ContactState: Int {
        case active = 0, inactive, invalid

        static let keyPath = #keyPath(ContactEntity.state)
    }
    
    @objc(ContactVerificationLevel) public enum VerificationLevel: Int {
        case unverified = 0, serverVerified, fullyVerified
    }
    
    @objc public enum ReadReceipt: Int {
        case `default` = 0, send, doNotSend

        static let keyPath = #keyPath(ContactEntity.readReceipts)
    }
    
    @objc public enum TypingIndicator: Int {
        case `default` = 0, send, doNotSend

        static let keyPath = #keyPath(ContactEntity.typingIndicators)
    }
    
    // MARK: Attributes
    
    @EncryptedField(name: "cnContactId")
    // swiftformat:disable:next acronyms
    @objc(cnContactId) public dynamic var cnContactID: String? {
        get {
            getCNContactID()
        }
        
        set {
            setCNContactID(newValue)
        }
    }
    
    @EncryptedField
    @objc public dynamic var createdAt: Date? {
        get {
            getCreatedAt()
        }
        
        set {
            setCreatedAt(newValue)
        }
    }
    
    @NSManaged public var csi: String?
    @NSManaged public var department: String?
    
    /// Current feature mask fetched for this contact
    ///
    /// Always set this when the feature masked is fetched, even if it didn't change. The CD property will not be update
    /// if there was no change.
    /// However, this will do some cleanup if FS is not supported with the set mask.
    @EncryptedField
    @objc public dynamic var featureMask: NSNumber {
        get {
            getFeatureMask()
        }
        
        set {
            setFeatureMask(newValue)
        }
    }
    
    @NSManaged public private(set) var firstName: String?
    
    /// Set or Get the forward security state of this contact. Note that these states are only maintained for contacts
    /// with a DH session of version 1.0.
    /// TODO(ANDR-2452): Remove the forward security state when most of clients support 1.1 anyway
    @EncryptedField
    @objc public dynamic var forwardSecurityState: NSNumber {
        get {
            getForwardSecurityState()
        }
        
        set {
            setForwardSecurityState(newValue)
        }
    }

    static let hiddenKeyPath = #keyPath(ContactEntity.hidden)
    @NSManaged private var hidden: NSNumber?

    @NSManaged public private(set) var identity: String
    
    /// Image data set from Contact of iOS
    @EncryptedField
    @objc public dynamic var imageData: Data? {
        get {
            getImageData()
        }
        
        set {
            setImageData(newValue)
        }
    }
    
    @EncryptedField
    @objc private dynamic var importStatus: NSNumber? {
        get {
            getImportStatus()
        }
        
        set {
            setImportStatus(newValue)
        }
    }
    
    @NSManaged public var jobTitle: String?
    @NSManaged public private(set) var lastName: String?

    @EncryptedField
    @objc public dynamic var profilePictureBlobID: String? {
        get {
            getProfilePictureBlobID()
        }
        
        set {
            setProfilePictureBlobID(newValue)
        }
    }
    
    @EncryptedField
    @objc private dynamic var profilePictureSended: NSNumber? {
        get {
            getProfilePictureSended()
        }
        
        set {
            setProfilePictureSended(newValue)
        }
    }
    
    @EncryptedField
    @objc public dynamic var profilePictureUpload: Date? {
        get {
            getProfilePictureUpload()
        }
        
        set {
            setProfilePictureUpload(newValue)
        }
    }
    
    @EncryptedField
    @objc public dynamic var publicKey: Data {
        get {
            getPublicKey()
        }
        
        set {
            setPublicKey(newValue)
        }
    }
    
    @NSManaged public var publicNickname: String?
    @NSManaged private var readReceipts: NSNumber
    @NSManaged public var sortIndex: NSNumber?
    @NSManaged public var sortInitial: String?
    @NSManaged private var state: NSNumber?
    @NSManaged private var typingIndicators: NSNumber
    
    @EncryptedField
    @objc private dynamic var verificationLevel: NSNumber {
        get {
            getVerificationLevel()
        }
        
        set {
            setVerificationLevel(newValue)
        }
    }
    
    @EncryptedField
    @objc public dynamic var verifiedEmail: String? {
        get {
            getVerifiedEmail()
        }
        
        set {
            setVerifiedEmail(newValue)
        }
    }
    
    @EncryptedField
    @objc public dynamic var verifiedMobileNo: String? {
        get {
            getVerifiedMobileNo()
        }
        
        set {
            setVerifiedMobileNo(newValue)
        }
    }
    
    /// This only means it's a verified contact from the admin (in the same work package). To check if this contact is a
    /// work ID, use the work identities list in user settings bad naming because of the history…
    @NSManaged public var workContact: NSNumber?
    
    // MARK: Custom getter/setter
    
    @objc public dynamic var contactImportStatus: ImportStatus {
        get {
            ImportStatus(rawValue: importStatus?.intValue ?? ImportStatus.initial.rawValue) ?? .initial
        }
        
        set {
            importStatus = newValue.rawValue as NSNumber
        }
    }
    
    @objc public dynamic var contactState: ContactState {
        get {
            ContactState(rawValue: state?.intValue ?? ContactState.inactive.rawValue) ?? .inactive
        }
        
        set {
            state = newValue.rawValue as NSNumber
        }
    }
    
    @objc public dynamic var isHidden: Bool {
        get {
            hidden?.boolValue ?? false
        }
        
        set {
            hidden = NSNumber(booleanLiteral: newValue)
        }
    }
    
    @objc public dynamic var profilePictureSent: Bool {
        get {
            profilePictureSended?.boolValue ?? false
        }
        
        set {
            profilePictureSended = NSNumber(booleanLiteral: newValue)
        }
    }
    
    @objc public dynamic var contactVerificationLevel: VerificationLevel {
        get {
            VerificationLevel(rawValue: verificationLevel.intValue) ?? .unverified
        }
        
        set {
            verificationLevel = newValue.rawValue as NSNumber
        }
    }
    
    @objc public dynamic var readReceipt: ReadReceipt {
        get {
            ReadReceipt(rawValue: readReceipts.intValue) ?? .default
        }
        
        set {
            readReceipts = newValue.rawValue as NSNumber
        }
    }
    
    @objc public dynamic var typingIndicator: TypingIndicator {
        get {
            TypingIndicator(rawValue: typingIndicators.intValue) ?? .default
        }
        
        set {
            typingIndicators = newValue.rawValue as NSNumber
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
    
    // MARK: Private properties

    // Cached decrypted values
    private var decryptedCnContactID: String?
    private var decryptedCreatedAt: Date?
    private var decryptedFeatureMask: Int64?
    private var decryptedForwardSecurityState: Int16? // Non optional
    private var decryptedImageData: Data?
    private var decryptedImportStatus: Int16?
    private var decryptedProfilePictureBlobID: String?
    private var decryptedProfilePictureSended: Bool?
    private var decryptedProfilePictureUpload: Date?
    private var decryptedPublicKey: Data? // Non optional
    private var decryptedVerificationLevel: Int16? // Non optional
    private var decryptedVerifiedEmail: String?
    private var decryptedVerifiedMobileNo: String?

    // MARK: - Lifecycle
    
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
    ///   - imageData: `Data` of the profile picture
    ///   - importStatus: Current import status of the contact
    ///   - jobTitle: Job title
    ///   - lastName: Last name
    ///   - profilePictureBlobID: BlobID of the profile picture
    ///   - profilePictureSended: If the profile picture was sent to the entity
    ///   - profilePictureUpload: When the profile picture was uploaded
    ///   - publicKey: Public key of the contact
    ///   - publicNickname: Nickname
    ///   - readReceipts: If we send read receipts to the contact
    ///   - sortIndex: Sort index of the entity in lists
    ///   - sortInitial: Initial the sortindex should be built upon
    ///   - state: Current state of the contact
    ///   - typingIndicators: If we send typing indicators to this contact
    ///   - verificationLevel: The current verification level
    ///   - verifiedEmail: The email of the contact
    ///   - verifiedMobileNo: The mobile number of the contact
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
        rejectedMessages: Set<BaseMessageEntity>? = nil,
        sortOrderFirstName: Bool
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "Contact", in: context)!
        super.init(entity: entity, insertInto: context)
        
        setCNContactID(cnContactID)
        if let createdAt {
            setCreatedAt(createdAt)
        }
        else {
            setCreatedAt(.now)
        }
        self.csi = csi
        self.department = department
        setFeatureMask(NSNumber(value: featureMask))
        self.firstName = firstName
        setForwardSecurityState(forwardSecurityState)
        self.hidden = hidden
        self.identity = identity
        setImageData(imageData)
        setImportStatus(importStatus)
        self.jobTitle = jobTitle
        self.lastName = lastName
        setProfilePictureBlobID(profilePictureBlobID)
        setProfilePictureSended(profilePictureSended)
        setProfilePictureUpload(profilePictureUpload)
        setPublicKey(publicKey)
        self.publicNickname = publicNickname
        self.readReceipts = readReceipts
        self.sortIndex = sortIndex
        self.sortInitial = sortInitial
        self.state = state
        self.typingIndicators = typingIndicators
        setVerificationLevel(verificationLevel)
        setVerifiedEmail(verifiedEmail)
        setVerifiedMobileNo(verifiedMobileNo)
        self.workContact = workContact
        
        self.contactImage = contactImage
        self.conversations = conversations
        self.groupConversations = groupConversations
        self.reactions = reactions
        self.rejectedMessages = rejectedMessages
        
        updateSortInitial(sortOrderFirstName: sortOrderFirstName)
    }
    
    convenience init(context: NSManagedObjectContext, identity: String, publicKey: Data, sortOrderFirstName: Bool) {
        self.init(
            context: context,
            featureMask: 0,
            forwardSecurityState: 0,
            identity: identity,
            publicKey: publicKey,
            readReceipts: 0,
            typingIndicators: 0,
            verificationLevel: 0,
            sortOrderFirstName: sortOrderFirstName
        )
    }
    
    @objc override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
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

    @objc public func setFirstName(to name: String?, sortOrderFirstName: Bool) {
        willChangeValue(for: \.firstName)
        setPrimitiveValue(name, forKey: "firstName")
        updateSortInitial(sortOrderFirstName: sortOrderFirstName)
        didChangeValue(for: \.firstName)
    }
    
    @objc public func setLastName(to name: String?, sortOrderFirstName: Bool) {
        willChangeValue(for: \.lastName)
        setPrimitiveValue(name, forKey: "lastName")
        updateSortInitial(sortOrderFirstName: sortOrderFirstName)
        didChangeValue(for: \.lastName)
    }
    
    @objc public func setIdentity(to id: String?, sortOrderFirstName: Bool) {
        willChangeValue(for: \.identity)
        setPrimitiveValue(id, forKey: "identity")
        updateSortInitial(sortOrderFirstName: sortOrderFirstName)
        didChangeValue(for: \.lastName)
    }
    
    @available(*, deprecated, message: "Only use for migration!")
    @objc public func getVerificationLevelForMigration() -> NSNumber {
        verificationLevel
    }
    
    // MARK: CNContactID

    private func getCNContactID() -> String? {
        var value: String?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedCnContactID, forKey: Self.encryptedCnContactIDName)
            value = decryptedCnContactID
        }
        else {
            willAccessValue(forKey: Self.cnContactIDName)
            value = primitiveValue(forKey: Self.cnContactIDName) as? String
            didAccessValue(forKey: Self.cnContactIDName)
        }
        return value
    }
    
    private func setCNContactID(_ newValue: String?) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedCnContactIDName)
            decryptedCnContactID = newValue
        }
        else {
            willChangeValue(forKey: Self.cnContactIDName)
            setPrimitiveValue(newValue, forKey: Self.cnContactIDName)
            didChangeValue(forKey: Self.cnContactIDName)
        }
    }
    
    // MARK: CreatedAt
    
    private func getCreatedAt() -> Date? {
        var value: Date?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedCreatedAt, forKey: Self.encryptedCreatedAtName)
            value = decryptedCreatedAt
        }
        else {
            willAccessValue(forKey: Self.createdAtName)
            value = primitiveValue(forKey: Self.createdAtName) as? Date
            didAccessValue(forKey: Self.createdAtName)
        }
        return value
    }
    
    private func setCreatedAt(_ newValue: Date?) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedCreatedAtName)
            decryptedCreatedAt = newValue
        }
        else {
            willChangeValue(forKey: Self.createdAtName)
            setPrimitiveValue(newValue, forKey: Self.createdAtName)
            didChangeValue(forKey: Self.createdAtName)
        }
    }
    
    // MARK: FeatureMask
    
    private func getFeatureMask() -> NSNumber {
        var value: NSNumber = 0 // Default value
        guard let managedObjectContext else {
            return 0
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedFeatureMask, forKey: Self.encryptedFeatureMaskName)
            if let decryptedFeatureMask {
                value = NSNumber(value: decryptedFeatureMask)
            }
        }
        else {
            willAccessValue(forKey: Self.featureMaskName)
            value = primitiveValue(forKey: Self.featureMaskName) as! NSNumber
            didAccessValue(forKey: Self.featureMaskName)
        }
        return value
    }
    
    private func setFeatureMask(_ newValue: NSNumber) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue.int64Value, forKey: Self.encryptedFeatureMaskName)
            decryptedFeatureMask = newValue.int64Value
        }
        else {
            willChangeValue(forKey: Self.featureMaskName)
            setPrimitiveValue(newValue, forKey: Self.featureMaskName)
            didChangeValue(forKey: Self.featureMaskName)
        }
    }
    
    // MARK: ForwardSecurityState
    
    private func getForwardSecurityState() -> NSNumber {
        var value: NSNumber = 0 // Default value
        guard let managedObjectContext else {
            return 0
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decrypt(&decryptedForwardSecurityState, forKey: Self.encryptedForwardSecurityStateName)
            if let decryptedForwardSecurityState {
                value = NSNumber(integerLiteral: Int(decryptedForwardSecurityState))
            }
        }
        else {
            willAccessValue(forKey: Self.forwardSecurityStateName)
            value = primitiveValue(forKey: Self.forwardSecurityStateName) as? NSNumber ?? value
            didAccessValue(forKey: Self.forwardSecurityStateName)
        }
        return value
    }
    
    private func setForwardSecurityState(_ newValue: NSNumber) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encrypt(newValue.int16Value, forKey: Self.encryptedForwardSecurityStateName)
            decryptedForwardSecurityState = newValue.int16Value
        }
        else {
            willChangeValue(forKey: Self.forwardSecurityStateName)
            setPrimitiveValue(newValue, forKey: Self.forwardSecurityStateName)
            didChangeValue(forKey: Self.forwardSecurityStateName)
        }
    }
    
    // MARK: ImageData
    
    private func getImageData() -> Data? {
        var value: Data?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedImageData, forKey: Self.encryptedImageDataName)
            value = decryptedImageData
        }
        else {
            willAccessValue(forKey: Self.imageDataName)
            value = primitiveValue(forKey: Self.imageDataName) as? Data
            didAccessValue(forKey: Self.imageDataName)
        }
        return value
    }
    
    private func setImageData(_ newValue: Data?) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedImageDataName)
            decryptedImageData = newValue
        }
        else {
            willChangeValue(forKey: Self.imageDataName)
            setPrimitiveValue(newValue, forKey: Self.imageDataName)
            didChangeValue(forKey: Self.imageDataName)
        }
    }
    
    // MARK: ImportStatus
    
    private func getImportStatus() -> NSNumber? {
        var value: NSNumber?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedImportStatus, forKey: Self.encryptedImportStatusName)
            if let decryptedImportStatus {
                value = NSNumber(integerLiteral: Int(decryptedImportStatus))
            }
        }
        else {
            willAccessValue(forKey: Self.importStatusName)
            value = primitiveValue(forKey: Self.importStatusName) as? NSNumber
            didAccessValue(forKey: Self.importStatusName)
        }
        return value
    }
    
    private func setImportStatus(_ newValue: NSNumber?) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue?.int16Value, forKey: Self.encryptedImportStatusName)
            decryptedImportStatus = newValue?.int16Value
        }
        else {
            willChangeValue(forKey: Self.importStatusName)
            setPrimitiveValue(newValue, forKey: Self.importStatusName)
            didChangeValue(forKey: Self.importStatusName)
        }
    }
    
    // MARK: ProfilePictureBlobID

    private func getProfilePictureBlobID() -> String? {
        var value: String?
        guard let managedObjectContext else {
            return nil
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(
                &decryptedProfilePictureBlobID,
                forKey: Self.encryptedProfilePictureBlobIDName
            )
            value = decryptedProfilePictureBlobID
        }
        else {
            willAccessValue(forKey: Self.profilePictureBlobIDName)
            value = primitiveValue(forKey: Self.profilePictureBlobIDName) as? String
            didAccessValue(forKey: Self.profilePictureBlobIDName)
        }
        return value
    }
    
    private func setProfilePictureBlobID(_ newValue: String?) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedProfilePictureBlobIDName)
            decryptedProfilePictureBlobID = newValue
        }
        else {
            willChangeValue(forKey: Self.profilePictureBlobIDName)
            setPrimitiveValue(newValue, forKey: Self.profilePictureBlobIDName)
            didChangeValue(forKey: Self.profilePictureBlobIDName)
        }
    }
    
    // MARK: ProfilePictureSended
    
    private func getProfilePictureSended() -> NSNumber? {
        var value: NSNumber?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(
                &decryptedProfilePictureSended,
                forKey: Self.encryptedProfilePictureSendedName
            )
            if let decryptedProfilePictureSended {
                value = NSNumber(booleanLiteral: decryptedProfilePictureSended)
            }
        }
        else {
            willAccessValue(forKey: Self.profilePictureSendedName)
            value = primitiveValue(forKey: Self.profilePictureSendedName) as? NSNumber
            didAccessValue(forKey: Self.profilePictureSendedName)
        }
        return value
    }
    
    private func setProfilePictureSended(_ newValue: NSNumber?) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue?.boolValue, forKey: Self.encryptedProfilePictureSendedName)
            decryptedProfilePictureSended = newValue?.boolValue
        }
        else {
            willChangeValue(forKey: Self.profilePictureSendedName)
            setPrimitiveValue(newValue, forKey: Self.profilePictureSendedName)
            didChangeValue(forKey: Self.profilePictureSendedName)
        }
    }

    // MARK: ProfilePictureUploadName
        
    private func getProfilePictureUpload() -> Date? {
        var value: Date?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(
                &decryptedProfilePictureUpload,
                forKey: Self.encryptedProfilePictureUploadName
            )
            value = decryptedProfilePictureUpload
        }
        else {
            willAccessValue(forKey: Self.profilePictureUploadName)
            value = primitiveValue(forKey: Self.profilePictureUploadName) as? Date
            didAccessValue(forKey: Self.profilePictureUploadName)
        }
        return value
    }
        
    private func setProfilePictureUpload(_ newValue: Date?) {
        guard let managedObjectContext else {
            return
        }
            
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedProfilePictureUploadName)
            decryptedProfilePictureUpload = newValue
        }
        else {
            willChangeValue(forKey: Self.profilePictureUploadName)
            setPrimitiveValue(newValue, forKey: Self.profilePictureUploadName)
            didChangeValue(forKey: Self.profilePictureUploadName)
        }
    }
    
    // MARK: PublicKey

    private func getPublicKey() -> Data {
        var value = Data()
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decrypt(&decryptedPublicKey, forKey: Self.encryptedPublicKeyName)
            if let decryptedPublicKey {
                value = decryptedPublicKey
            }
        }
        else {
            willAccessValue(forKey: Self.publicKeyName)
            value = primitiveValue(forKey: Self.publicKeyName) as? Data ?? value
            didAccessValue(forKey: Self.publicKeyName)
        }
        return value
    }
    
    private func setPublicKey(_ newValue: Data) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encrypt(newValue, forKey: Self.encryptedPublicKeyName)
            decryptedPublicKey = newValue
        }
        else {
            willChangeValue(forKey: Self.publicKeyName)
            setPrimitiveValue(newValue, forKey: Self.publicKeyName)
            didChangeValue(forKey: Self.publicKeyName)
        }
    }
    
    // MARK: VerificationLevel
    
    private func getVerificationLevel() -> NSNumber {
        var value: NSNumber = 0 // Default value
        guard let managedObjectContext else {
            return 0
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decrypt(&decryptedVerificationLevel, forKey: Self.encryptedVerificationLevelName)
            if let decryptedVerificationLevel {
                value = NSNumber(integerLiteral: Int(decryptedVerificationLevel))
            }
        }
        else {
            willAccessValue(forKey: Self.verificationLevelName)
            value = primitiveValue(forKey: Self.verificationLevelName) as? NSNumber ?? value
            didAccessValue(forKey: Self.verificationLevelName)
        }
        return value
    }
    
    private func setVerificationLevel(_ newValue: NSNumber) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encrypt(newValue.int16Value, forKey: Self.encryptedVerificationLevelName)
            decryptedVerificationLevel = newValue.int16Value
        }
        else {
            willChangeValue(forKey: Self.verificationLevelName)
            setPrimitiveValue(newValue, forKey: Self.verificationLevelName)
            didChangeValue(forKey: Self.verificationLevelName)
        }
    }
    
    // MARK: VerifiedEmail

    private func getVerifiedEmail() -> String? {
        var value: String?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedVerifiedEmail, forKey: Self.encryptedVerifiedEmailName)
            value = decryptedVerifiedEmail
        }
        else {
            willAccessValue(forKey: Self.verifiedEmailName)
            value = primitiveValue(forKey: Self.verifiedEmailName) as? String
            didAccessValue(forKey: Self.verifiedEmailName)
        }
        return value
    }
    
    private func setVerifiedEmail(_ newValue: String?) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedVerifiedEmailName)
            decryptedVerifiedEmail = newValue
        }
        else {
            willChangeValue(forKey: Self.verifiedEmailName)
            setPrimitiveValue(newValue, forKey: Self.verifiedEmailName)
            didChangeValue(forKey: Self.verifiedEmailName)
        }
    }
    
    // MARK: VerifiedMobileNo

    private func getVerifiedMobileNo() -> String? {
        var value: String?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedVerifiedMobileNo, forKey: Self.encryptedVerifiedMobileNoName)
            value = decryptedVerifiedMobileNo
        }
        else {
            willAccessValue(forKey: Self.verifiedMobileNoName)
            value = primitiveValue(forKey: Self.verifiedMobileNoName) as? String
            didAccessValue(forKey: Self.verifiedMobileNoName)
        }
        return value
    }
    
    private func setVerifiedMobileNo(_ newValue: String?) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedVerifiedMobileNoName)
            decryptedVerifiedMobileNo = newValue
        }
        else {
            willChangeValue(forKey: Self.verifiedMobileNoName)
            setPrimitiveValue(newValue, forKey: Self.verifiedMobileNoName)
            didChangeValue(forKey: Self.verifiedMobileNoName)
        }
    }
    
    // MARK: - Reset cached values

    override public func didChangeValue(forKey key: String) {
        if key == Self.encryptedCnContactIDName {
            decryptedCnContactID = nil
        }
        else if key == Self.encryptedCreatedAtName {
            decryptedCreatedAt = nil
        }
        else if key == Self.encryptedFeatureMaskName {
            decryptedFeatureMask = nil
        }
        else if key == Self.encryptedForwardSecurityStateName {
            decryptedForwardSecurityState = nil
        }
        else if key == Self.encryptedImageDataName {
            decryptedImageData = nil
        }
        else if key == Self.encryptedImportStatusName {
            decryptedImportStatus = nil
        }
        else if key == Self.encryptedProfilePictureBlobIDName {
            decryptedProfilePictureBlobID = nil
        }
        else if key == Self.encryptedProfilePictureSendedName {
            decryptedProfilePictureSended = nil
        }
        else if key == Self.encryptedProfilePictureUploadName {
            decryptedProfilePictureUpload = nil
        }
        else if key == Self.encryptedPublicKeyName {
            decryptedPublicKey = nil
        }
        else if key == Self.encryptedVerificationLevelName {
            decryptedVerificationLevel = nil
        }
        else if key == Self.encryptedVerifiedEmailName {
            decryptedVerifiedEmail = nil
        }
        else if key == Self.encryptedVerifiedMobileNoName {
            decryptedVerifiedMobileNo = nil
        }
        super.didChangeValue(forKey: key)
    }

    override public func didTurnIntoFault() {
        decryptedCnContactID = nil
        decryptedCreatedAt = nil
        decryptedFeatureMask = nil
        decryptedForwardSecurityState = nil
        decryptedImageData = nil
        decryptedImportStatus = nil
        decryptedProfilePictureBlobID = nil
        decryptedProfilePictureSended = nil
        decryptedProfilePictureUpload = nil
        decryptedPublicKey = nil
        decryptedVerificationLevel = nil
        decryptedVerifiedEmail = nil
        decryptedVerifiedMobileNo = nil
        super.didTurnIntoFault()
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
