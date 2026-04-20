import CoreData
import Foundation
import ThreemaMacros

/// Result might be a little misleading, in simpler terms, this is a vote by a participant.
@objc(BallotResultEntity)
public final class BallotResultEntity: ThreemaManagedObject {

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

    @EncryptedField
    @objc public dynamic var modifyDate: Date? {
        get {
            getModifyDate()
        }

        set {
            setModifyDate(newValue)
        }
    }

    // swiftformat:disable:next acronyms
    @NSManaged @objc(participantId) public var participantID: String

    @EncryptedField
    @objc public dynamic var value: NSNumber? {
        get {
            getValue()
        }

        set {
            setValue(newValue)
        }
    }

    // MARK: Relationships

    @NSManaged public var ballotChoice: BallotChoiceEntity

    // MARK: Private properties

    // Cached decrypted values
    private var decryptedCreateDate: Date?
    private var decryptedModifyDate: Date?
    private var decryptedValue: Int16?

    // MARK: - Lifecycle

    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: `NSManagedObjectContext` to insert created entity into
    ///   - createDate: `Date` when created
    ///   - modifyDate: `Date` when last modified
    ///   - participantID: ID of the participant
    ///   - value: Value of the result
    ///   - ballotChoice: `BallotChoiceEntity` the result belongs to
    init(
        context: NSManagedObjectContext,
        createDate: Date? = nil,
        modifyDate: Date? = nil,
        participantID: String,
        value: Bool? = nil,
        ballotChoice: BallotChoiceEntity
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "BallotResult", in: context)!
        super.init(entity: entity, insertInto: context)

        setCreateDate(createDate)
        setModifyDate(modifyDate)
        self.participantID = participantID
        if let value {
            setValue(value as NSNumber)
        }

        self.ballotChoice = ballotChoice
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
        guard let managedObjectContext else {
            return .now
        }

        var value: Date?
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

    // MARK: Value

    private func getValue() -> NSNumber? {
        var value: NSNumber?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedValue, forKey: Self.encryptedValueName)
            if let decryptedValue {
                value = NSNumber(integerLiteral: Int(decryptedValue))
            }
        }
        else {
            willAccessValue(forKey: Self.valueName)
            value = primitiveValue(forKey: Self.valueName) as? NSNumber
            didAccessValue(forKey: Self.valueName)
        }
        return value
    }

    private func setValue(_ newValue: NSNumber?) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue?.int16Value, forKey: Self.encryptedValueName)
            decryptedValue = newValue?.int16Value
        }
        else {
            willChangeValue(forKey: Self.valueName)
            setPrimitiveValue(newValue, forKey: Self.valueName)
            didChangeValue(forKey: Self.valueName)
        }
    }

    // MARK: - Reset cached values

    override public func didChangeValue(forKey key: String) {
        if key == Self.encryptedCreateDateName {
            decryptedCreateDate = nil
        }
        else if key == Self.encryptedModifyDateName {
            decryptedModifyDate = nil
        }
        else if key == Self.encryptedValueName {
            decryptedValue = nil
        }
        super.didChangeValue(forKey: key)
    }

    override public func didTurnIntoFault() {
        decryptedCreateDate = nil
        decryptedModifyDate = nil
        decryptedValue = nil
        super.didTurnIntoFault()
    }
}
