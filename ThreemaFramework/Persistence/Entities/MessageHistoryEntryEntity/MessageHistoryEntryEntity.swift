import CoreData
import Foundation
import ThreemaMacros

@objc(MessageHistoryEntryEntity)
public final class MessageHistoryEntryEntity: ThreemaManagedObject, Identifiable {

    // MARK: Attributes

    @NSManaged public var editDate: Date

    @EncryptedField
    @objc public dynamic var text: String? {
        get {
            getText()
        }

        set {
            setText(newValue)
        }
    }

    // MARK: Relationships

    @NSManaged public private(set) var message: BaseMessageEntity

    // MARK: Private properties

    // Cached decrypted values
    private var decryptedText: String?

    // MARK: - Lifecycle

    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: `NSManagedObjectContext` to insert created entity into
    ///   - editDate: Date entry was created
    ///   - text: Text of the entry
    ///   - message: `BaseMessageEntity` the entity belongs to
    init(
        context: NSManagedObjectContext,
        editDate: Date,
        text: String? = nil,
        message: BaseMessageEntity
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "MessageHistoryEntry", in: context)!
        super.init(entity: entity, insertInto: context)

        self.editDate = editDate
        setText(text)

        self.message = message
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

    // MARK: Text

    private func getText() -> String? {
        var value: String?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedText, forKey: Self.encryptedTextName)
            value = decryptedText
        }
        else {
            willAccessValue(forKey: Self.textName)
            value = primitiveValue(forKey: Self.textName) as? String
            didAccessValue(forKey: Self.textName)
        }
        return value
    }

    private func setText(_ newValue: String?) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedTextName)
            decryptedText = newValue
        }
        else {
            willChangeValue(forKey: Self.textName)
            setPrimitiveValue(newValue, forKey: Self.textName)
            didChangeValue(forKey: Self.textName)
        }
    }

    // MARK: - Reset cached values

    override public func didChangeValue(forKey key: String) {
        if key == Self.encryptedTextName {
            decryptedText = nil
        }
        super.didChangeValue(forKey: key)
    }

    override public func didTurnIntoFault() {
        decryptedText = nil
        super.didTurnIntoFault()
    }
}
