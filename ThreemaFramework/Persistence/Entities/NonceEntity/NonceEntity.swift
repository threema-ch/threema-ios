import CoreData
import Foundation

@objc(NonceEntity)
public final class NonceEntity: ThreemaManagedObject {
    
    // MARK: Attributes

    @NSManaged public var nonce: Data
    
    // MARK: - Lifecycle
    
    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: `NSManagedObjectContext` to insert created entity into
    ///   - nonce: `Data` of nonce to be saved
    init(context: NSManagedObjectContext, nonce: Data) {
        let entity = NSEntityDescription.entity(forEntityName: "Nonce", in: context)!
        super.init(entity: entity, insertInto: context)
        
        self.nonce = nonce
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
}
