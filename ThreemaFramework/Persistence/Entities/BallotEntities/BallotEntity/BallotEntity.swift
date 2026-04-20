import CoreData
import Foundation
import ThreemaMacros

@objc(BallotEntity)
public final class BallotEntity: ThreemaManagedObject {
    
    // MARK: Attributes

    @EncryptedField
    @objc public dynamic var assessmentType: NSNumber? {
        get {
            getAssessmentType()
        }
        
        set {
            setAssessmentType(newValue)
        }
    }
    
    @EncryptedField
    @objc public dynamic var choicesType: NSNumber? {
        get {
            getChoicesType()
        }
        
        set {
            setChoicesType(newValue)
        }
    }
    
    @NSManaged public var createDate: Date?
    // swiftformat:disable:next acronyms
    @NSManaged @objc(creatorId) public var creatorID: String?

    @EncryptedField
    @objc public dynamic var displayMode: NSNumber? {
        get {
            getDisplayMode()
        }
        
        set {
            setDisplayMode(newValue)
        }
    }
    
    @NSManaged public var id: Data
    @NSManaged public var modifyDate: Date?
    @NSManaged public var state: NSNumber?

    @EncryptedField
    @objc public dynamic var title: String? {
        get {
            getTitle()
        }
        
        set {
            setTitle(newValue)
        }
    }
    
    @EncryptedField
    @objc public dynamic var type: NSNumber? {
        get {
            getType()
        }
        
        set {
            setType(newValue)
        }
    }
    
    // MARK: Relationships

    @NSManaged public var choices: Set<BallotChoiceEntity>?
    @NSManaged public var conversation: ConversationEntity?
    @NSManaged public var message: Set<BallotMessageEntity>?
    @NSManaged public var participants: Set<ContactEntity>?
    
    // MARK: Private properties
    
    // Cached decrypted values
    private var decryptedAssessmentType: Int16?
    private var decryptedChoicesType: Int16?
    private var decryptedDisplayMode: Int16?
    private var decryptedTitle: String?
    private var decryptedType: Int16?

    // MARK: - Lifecycle

    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: `NSManagedObjectContext` to insert created entity into
    ///   - assessmentType: `BallotAssessmentType`, single- / multiple-choice
    ///   - choicesType: Type of choices
    ///   - createDate: Date of creation
    ///   - creatorID: ID of creator
    ///   - displayMode: `BallotDisplayMode`, list or summary
    ///   - id: ID of the ballot
    ///   - modifyDate: `Date` of last modification
    ///   - state: `BallotState` Open or closed
    ///   - title: Title of the ballot
    ///   - type: `BallotType`, intermediate or closed
    ///   - choices: Set of `BallotChoiceEntity` belonging to the ballot
    ///   - conversation: `ConversationEntity` the ballot belongs to
    ///   - message: Set of `BallotMessageEntity` belonging to the ballot
    ///   - participants: Set `ContactEntity` participating in the ballot
    init(
        context: NSManagedObjectContext,
        assessmentType: BallotAssessmentType?,
        createDate: Date? = nil,
        creatorID: String? = nil,
        displayMode: BallotDisplayMode? = .list,
        id: Data,
        modifyDate: Date? = nil,
        state: BallotState?,
        title: String? = nil,
        type: BallotType?,
        choices: Set<BallotChoiceEntity>? = nil,
        conversation: ConversationEntity? = nil,
        message: Set<BallotMessageEntity>? = nil,
        participants: Set<ContactEntity>? = nil
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "Ballot", in: context)!
        super.init(entity: entity, insertInto: context)

        if let assessmentType {
            setAssessmentType(assessmentType.rawValue as NSNumber)
        }
        setChoicesType(0)
        self.createDate = createDate
        self.creatorID = creatorID
        if let displayMode {
            setDisplayMode(displayMode.rawValue as NSNumber)
        }
        self.id = id
        self.modifyDate = modifyDate
        if let state {
            self.state = state.rawValue as NSNumber
        }
        setTitle(title)
        if let type {
            setType(type.rawValue as NSNumber)
        }
        
        self.choices = choices
        self.conversation = conversation
        self.message = message
        self.participants = participants
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

    // MARK: AssessmentType
    
    private func getAssessmentType() -> NSNumber? {
        var value: NSNumber?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedAssessmentType, forKey: Self.encryptedAssessmentTypeName)
            if let decryptedAssessmentType {
                value = NSNumber(integerLiteral: Int(decryptedAssessmentType))
            }
        }
        else {
            willAccessValue(forKey: Self.assessmentTypeName)
            value = primitiveValue(forKey: Self.assessmentTypeName) as? NSNumber
            didAccessValue(forKey: Self.assessmentTypeName)
        }
        return value
    }
    
    private func setAssessmentType(_ newValue: NSNumber?) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue?.int16Value, forKey: Self.encryptedAssessmentTypeName)
            decryptedAssessmentType = newValue?.int16Value
        }
        else {
            willChangeValue(forKey: Self.assessmentTypeName)
            setPrimitiveValue(newValue, forKey: Self.assessmentTypeName)
            didChangeValue(forKey: Self.assessmentTypeName)
        }
    }
    
    // MARK: ChoicesType
    
    private func getChoicesType() -> NSNumber? {
        var value: NSNumber?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedChoicesType, forKey: Self.encryptedChoicesTypeName)
            if let decryptedChoicesType {
                value = NSNumber(integerLiteral: Int(decryptedChoicesType))
            }
        }
        else {
            willAccessValue(forKey: Self.choicesTypeName)
            value = primitiveValue(forKey: Self.choicesTypeName) as? NSNumber
            didAccessValue(forKey: Self.choicesTypeName)
        }
        return value
    }
    
    private func setChoicesType(_ newValue: NSNumber?) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue?.int16Value, forKey: Self.encryptedChoicesTypeName)
            decryptedChoicesType = newValue?.int16Value
        }
        else {
            willChangeValue(forKey: Self.choicesTypeName)
            setPrimitiveValue(newValue, forKey: Self.choicesTypeName)
            didChangeValue(forKey: Self.choicesTypeName)
        }
    }
    
    // MARK: DisplayMode
    
    private func getDisplayMode() -> NSNumber? {
        var value: NSNumber?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedDisplayMode, forKey: Self.encryptedDisplayModeName)
            if let decryptedDisplayMode {
                value = NSNumber(integerLiteral: Int(decryptedDisplayMode))
            }
        }
        else {
            willAccessValue(forKey: Self.displayModeName)
            value = primitiveValue(forKey: Self.displayModeName) as? NSNumber
            didAccessValue(forKey: Self.displayModeName)
        }
        return value
    }
    
    private func setDisplayMode(_ newValue: NSNumber?) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue?.int16Value, forKey: Self.encryptedDisplayModeName)
            decryptedDisplayMode = newValue?.int16Value
        }
        else {
            willChangeValue(forKey: Self.displayModeName)
            setPrimitiveValue(newValue, forKey: Self.displayModeName)
            didChangeValue(forKey: Self.displayModeName)
        }
    }
    
    // MARK: Title

    private func getTitle() -> String? {
        var value: String?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedTitle, forKey: Self.encryptedTitleName)
            value = decryptedTitle
        }
        else {
            willAccessValue(forKey: Self.titleName)
            value = primitiveValue(forKey: Self.titleName) as? String
            didAccessValue(forKey: Self.titleName)
        }

        return value
    }
    
    private func setTitle(_ newValue: String?) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedTitleName)
            decryptedTitle = newValue
        }
        else {
            willChangeValue(forKey: Self.titleName)
            setPrimitiveValue(newValue, forKey: Self.titleName)
            didChangeValue(forKey: Self.titleName)
        }
    }
    
    // MARK: Type
    
    private func getType() -> NSNumber? {
        var value: NSNumber?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedType, forKey: Self.encryptedTypeName)
            if let decryptedType {
                value = NSNumber(integerLiteral: Int(decryptedType))
            }
        }
        else {
            willAccessValue(forKey: Self.typeName)
            value = primitiveValue(forKey: Self.typeName) as? NSNumber
            didAccessValue(forKey: Self.typeName)
        }
        return value
    }
    
    private func setType(_ newValue: NSNumber?) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue?.int16Value, forKey: Self.encryptedTypeName)
            decryptedType = newValue?.int16Value
        }
        else {
            willChangeValue(forKey: Self.typeName)
            setPrimitiveValue(newValue, forKey: Self.typeName)
            didChangeValue(forKey: Self.typeName)
        }
    }
    
    // MARK: - Clearing cached values

    override public func didChangeValue(forKey key: String) {
        if key == Self.encryptedAssessmentTypeName {
            decryptedAssessmentType = nil
        }
        else if key == Self.encryptedChoicesTypeName {
            decryptedChoicesType = nil
        }
        else if key == Self.encryptedDisplayModeName {
            decryptedDisplayMode = nil
        }
        else if key == Self.encryptedTitleName {
            decryptedTitle = nil
        }
        else if key == Self.encryptedTypeName {
            decryptedType = nil
        }
        super.didChangeValue(forKey: key)
    }

    override public func didTurnIntoFault() {
        decryptedAssessmentType = nil
        decryptedChoicesType = nil
        decryptedDisplayMode = nil
        decryptedTitle = nil
        decryptedType = nil
        super.didTurnIntoFault()
    }

    // MARK: Generated accessors for choices

    @objc(addChoicesObject:)
    @NSManaged public func addToChoices(_ value: BallotChoiceEntity)

    @objc(removeChoicesObject:)
    @NSManaged public func removeFromChoices(_ value: BallotChoiceEntity)

    @objc(addChoices:)
    @NSManaged public func addToChoices(_ values: NSSet)

    @objc(removeChoices:)
    @NSManaged public func removeFromChoices(_ values: NSSet)
    
    // MARK: Generated accessors for message

    @objc(addMessageObject:)
    @NSManaged public func addToMessage(_ value: BallotMessageEntity)

    @objc(removeMessageObject:)
    @NSManaged public func removeFromMessage(_ value: BallotMessageEntity)

    @objc(addMessage:)
    @NSManaged public func addToMessage(_ values: NSSet)

    @objc(removeMessage:)
    @NSManaged public func removeFromMessage(_ values: NSSet)
    
    // MARK: Generated accessors for participants

    @objc(addParticipantsObject:)
    @NSManaged public func addToParticipants(_ value: ContactEntity)

    @objc(removeParticipantsObject:)
    @NSManaged public func removeFromParticipants(_ value: ContactEntity)

    @objc(addParticipants:)
    @NSManaged public func addToParticipants(_ values: NSSet)

    @objc(removeParticipants:)
    @NSManaged public func removeFromParticipants(_ values: NSSet)
}
