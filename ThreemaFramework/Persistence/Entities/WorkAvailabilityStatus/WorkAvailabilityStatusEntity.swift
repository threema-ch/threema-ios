import CoreData
import Foundation
import ThreemaMacros

@objc(WorkAvailabilityStatusEntity)
public final class WorkAvailabilityStatusEntity: ThreemaManagedObject, Identifiable {
    
    // MARK: - Attributes

    @EncryptedField
    @objc public dynamic var text: String? {
        get {
            getText()
        }

        set {
            setText(newValue)
        }
    }
    
    @EncryptedField
    @objc public dynamic var value: NSNumber {
        get {
            getValue()
        }

        set {
            setValue(newValue)
        }
    }
    
    // MARK: - Relationships
    
    @NSManaged public private(set) var contact: ContactEntity
    
    // MARK: Private properties

    // Cached decrypted values
    private var decryptedText: String?
    private var decryptedValue: Int64? // Non optional

    // MARK: - Lifecycle
    
    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: `NSManagedObjectContext` to insert created entity into
    ///   - value: Value of the status
    ///   - text: Custom text belonging to the status
    ///   - contact: `ContactEntity` the entity belongs to
    init(context: NSManagedObjectContext, value: Int, text: String? = nil, contact: ContactEntity) {
        let entity = NSEntityDescription.entity(forEntityName: "WorkAvailabilityStatus", in: context)!
        super.init(entity: entity, insertInto: context)
        
        setValue(NSNumber(value: value))
        setText(text)
        self.contact = contact
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

    // MARK: Description

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
        
        let trimmedText = trimText(text: newValue)
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(trimmedText, forKey: Self.encryptedTextName)
            decryptedText = trimmedText
        }
        else {
            willChangeValue(forKey: Self.textName)
            setPrimitiveValue(trimmedText, forKey: Self.textName)
            didChangeValue(forKey: Self.textName)
        }
    }
    
    private func getValue() -> NSNumber {
        guard let managedObjectContext else {
            return 0
        }

        var value: NSNumber = 0 // Default value
        if managedObjectContext.usesAdditionallyEncryptedModel {
            decrypt(&decryptedValue, forKey: Self.encryptedValueName)
            if let decryptedValue {
                value = NSNumber(value: decryptedValue)
            }
        }
        else {
            willAccessValue(forKey: Self.valueName)
            value = primitiveValue(forKey: Self.valueName) as? NSNumber ?? 0
            didAccessValue(forKey: Self.valueName)
        }
        return value
    }

    private func setValue(_ newValue: NSNumber) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encrypt(newValue.int64Value, forKey: Self.encryptedValueName)
            decryptedValue = newValue.int64Value
        }
        else {
            willChangeValue(forKey: Self.valueName)
            setPrimitiveValue(newValue, forKey: Self.valueName)
            didChangeValue(forKey: Self.valueName)
        }
    }
    
    // MARK: - Helpers
    
    private func trimText(text: String?) -> String? {
        guard let text else {
            return nil
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    
    // MARK: - Reset cached values

    override public func didChangeValue(forKey key: String) {
        if key == Self.encryptedTextName {
            decryptedText = nil
        }
        if key == Self.encryptedValueName {
            decryptedValue = nil
        }
        super.didChangeValue(forKey: key)
    }

    override public func didTurnIntoFault() {
        decryptedText = nil
        decryptedValue = nil
        super.didTurnIntoFault()
    }
}
