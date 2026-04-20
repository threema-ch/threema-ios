import CoreData
import Foundation
import ThreemaMacros

@objc(MessageMarkersEntity)
public final class MessageMarkersEntity: ThreemaManagedObject, Identifiable {

    // MARK: Attributes

    @EncryptedField
    @objc public dynamic var star: NSNumber {
        get {
            getStar()
        }

        set {
            setStar(newValue)
        }
    }

    // MARK: Relationships

    @NSManaged public var message: BaseMessageEntity?

    // MARK: Private properties

    // Cached decrypted values
    private var decryptedStar: Bool?

    // MARK: - Lifecycle

    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: `NSManagedObjectContext` to insert created entity into
    ///   - star: Bool value if message is starred
    ///   - message: `BaseMessageEntity` the entity belongs to
    init(context: NSManagedObjectContext, star: Bool = false, message: BaseMessageEntity? = nil) {
        let entity = NSEntityDescription.entity(forEntityName: "MessageMarkers", in: context)!
        super.init(entity: entity, insertInto: context)

        setStar(NSNumber(booleanLiteral: star))

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

    // MARK: Star

    private func getStar() -> NSNumber {
        var value: NSNumber = 0 // Default value
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decrypt(&decryptedStar, forKey: Self.encryptedStarName)
            if let decryptedStar {
                value = NSNumber(booleanLiteral: decryptedStar)
            }
        }
        else {
            willAccessValue(forKey: Self.starName)
            value = primitiveValue(forKey: Self.starName) as? NSNumber ?? value
            didAccessValue(forKey: Self.starName)
        }
        return value
    }

    private func setStar(_ newValue: NSNumber) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encrypt(newValue.boolValue, forKey: Self.encryptedStarName)
            decryptedStar = newValue.boolValue
        }
        else {
            willChangeValue(forKey: Self.starName)
            setPrimitiveValue(newValue, forKey: Self.starName)
            didChangeValue(forKey: Self.starName)
        }
    }

    // MARK: - Reset cached values

    override public func didChangeValue(forKey key: String) {
        if key == Self.encryptedStarName {
            decryptedStar = nil
        }
        super.didChangeValue(forKey: key)
    }

    override public func didTurnIntoFault() {
        decryptedStar = nil
        super.didTurnIntoFault()
    }
}
