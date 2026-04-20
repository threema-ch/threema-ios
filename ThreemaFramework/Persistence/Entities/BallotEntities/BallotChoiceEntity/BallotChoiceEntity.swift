import CoreData
import Foundation
import ThreemaMacros

@objc(BallotChoiceEntity)
public final class BallotChoiceEntity: ThreemaManagedObject {
    
    // MARK: Attributes

    @EncryptedField
    @objc public dynamic var createDate: Date? {
        get {
            getCreateDate()
        }
        
        set {
            setCreateDate(newValue)
        }
    }
    
    @NSManaged public var id: NSNumber
    
    @EncryptedField
    @objc public dynamic var modifyDate: Date? {
        get {
            getModifyDate()
        }
        
        set {
            setModifyDate(newValue)
        }
    }
    
    @EncryptedField
    @objc public dynamic var name: String? {
        get {
            getName()
        }
        
        set {
            setName(newValue)
        }
    }
    
    @NSManaged public var orderPosition: NSNumber?
    
    @EncryptedField
    @objc public dynamic var totalVotes: NSNumber? {
        get {
            getTotalVotes()
        }
        
        set {
            setTotalVotes(newValue)
        }
    }
    
    // MARK: Relationships

    @NSManaged public var ballot: BallotEntity
    @NSManaged public var result: Set<BallotResultEntity>?
    
    // MARK: Private properties
    
    // Cached decrypted values
    private var decryptedCreateDate: Date?
    private var decryptedModifyDate: Date?
    private var decryptedName: String?
    private var decryptedTotalVotes: Int32?

    // MARK: - Lifecycle
    
    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: `NSManagedObjectContext` to insert created entity into
    ///   - createDate: `Date` of the creation
    ///   - id: ID of the choice
    ///   - modifyDate: `Date` last modified
    ///   - name: Name of the choice
    ///   - orderPosition: Position of the choice for ordering
    ///   - totalVotes: Amount of votes for the choice
    ///   - ballot: `BallotEntity` the entity belongs to
    ///   - result: Set of `BallotResultEntity` belonging to the choice
    init(
        context: NSManagedObjectContext,
        createDate: Date? = nil,
        id: NSNumber,
        modifyDate: Date? = nil,
        name: String? = nil,
        orderPosition: NSNumber? = nil,
        totalVotes: NSNumber? = nil,
        ballot: BallotEntity,
        result: Set<BallotResultEntity>? = nil
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "BallotChoice", in: context)!
        super.init(entity: entity, insertInto: context)
        
        setCreateDate(createDate)
        self.id = id
        setModifyDate(modifyDate)
        setName(name)
        self.orderPosition = orderPosition
        setTotalVotes(totalVotes)
        
        self.ballot = ballot
        self.result = result
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

    // MARK: CreateDate

    private func getCreateDate() -> Date? {
        var value: Date?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedCreateDate, forKey: Self.encryptedCreateDateName)
            value = decryptedCreateDate
        }
        else {
            willAccessValue(forKey: Self.createDateName)
            value = primitiveValue(forKey: Self.createDateName) as? Date
            didAccessValue(forKey: Self.createDateName)
        }
        return value
    }
    
    private func setCreateDate(_ newValue: Date?) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedCreateDateName)
            decryptedCreateDate = newValue
        }
        else {
            willChangeValue(forKey: Self.createDateName)
            setPrimitiveValue(newValue, forKey: Self.createDateName)
            didChangeValue(forKey: Self.createDateName)
        }
    }
    
    // MARK: ModifyDate
    
    private func getModifyDate() -> Date? {
        var value: Date?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedModifyDate, forKey: Self.encryptedModifyDateName)
            value = decryptedModifyDate
        }
        else {
            willAccessValue(forKey: Self.modifyDateName)
            value = primitiveValue(forKey: Self.modifyDateName) as? Date
            didAccessValue(forKey: Self.modifyDateName)
        }
        return value
    }
    
    private func setModifyDate(_ newValue: Date?) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedModifyDateName)
            decryptedModifyDate = newValue
        }
        else {
            willChangeValue(forKey: Self.modifyDateName)
            setPrimitiveValue(newValue, forKey: Self.modifyDateName)
            didChangeValue(forKey: Self.modifyDateName)
        }
    }
    
    // MARK: Name

    private func getName() -> String? {
        var value: String?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedName, forKey: Self.encryptedNameName)
            value = decryptedName
        }
        else {
            willAccessValue(forKey: Self.nameName)
            value = primitiveValue(forKey: Self.nameName) as? String
            didAccessValue(forKey: Self.nameName)
        }
        return value
    }
    
    private func setName(_ newValue: String?) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedNameName)
            decryptedName = newValue
        }
        else {
            willChangeValue(forKey: Self.nameName)
            setPrimitiveValue(newValue, forKey: Self.nameName)
            didChangeValue(forKey: Self.nameName)
        }
    }
    
    // MARK: TotalVotes
    
    private func getTotalVotes() -> NSNumber? {
        var value: NSNumber?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedTotalVotes, forKey: Self.encryptedTotalVotesName)
            if let decryptedTotalVotes {
                value = NSNumber(integerLiteral: Int(decryptedTotalVotes))
            }
        }
        else {
            willAccessValue(forKey: Self.totalVotesName)
            value = primitiveValue(forKey: Self.totalVotesName) as? NSNumber
            didAccessValue(forKey: Self.totalVotesName)
        }
        return value
    }
    
    private func setTotalVotes(_ newValue: NSNumber?) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue?.int32Value, forKey: Self.encryptedTotalVotesName)
            decryptedTotalVotes = newValue?.int32Value
        }
        else {
            willChangeValue(forKey: Self.totalVotesName)
            setPrimitiveValue(newValue, forKey: Self.totalVotesName)
            didChangeValue(forKey: Self.totalVotesName)
        }
    }
    
    // MARK: - Clearing cached values

    override public func didChangeValue(forKey key: String) {
        if key == Self.encryptedCreateDateName {
            decryptedCreateDate = nil
        }
        else if key == Self.encryptedModifyDateName {
            decryptedModifyDate = nil
        }
        else if key == Self.encryptedNameName {
            decryptedName = nil
        }
        else if key == Self.encryptedTotalVotesName {
            decryptedTotalVotes = nil
        }
        super.didChangeValue(forKey: key)
    }

    override public func didTurnIntoFault() {
        decryptedCreateDate = nil
        decryptedModifyDate = nil
        decryptedName = nil
        decryptedTotalVotes = nil
        super.didTurnIntoFault()
    }

    // MARK: - Generated accessors for result

    @objc(addResultObject:)
    @NSManaged public func addToResult(_ value: BallotResultEntity)

    @objc(removeResultObject:)
    @NSManaged public func removeFromResult(_ value: BallotResultEntity)

    @objc(addResult:)
    @NSManaged public func addToResult(_ values: NSSet)

    @objc(removeResult:)
    @NSManaged public func removeFromResult(_ values: NSSet)
}
