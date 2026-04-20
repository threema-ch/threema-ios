import CoreData
import Foundation

@objc(CallEntity)
public final class CallEntity: ThreemaManagedObject {
    
    // MARK: Attributes

    @NSManaged public var callID: NSNumber?
    @NSManaged public var date: Date?
   
    // MARK: Relationships

    @NSManaged public var contact: ContactEntity?
    
    // MARK: - Lifecycle
    
    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: NSManagedObjectContext to insert created entity into
    ///   - callID: ID of the call
    ///   - date: Date the call was started
    ///   - contactEntity: Contact the call was held with
    init(
        context: NSManagedObjectContext,
        callID: Int32? = nil,
        date: Date? = nil,
        contactEntity: ContactEntity?
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "Call", in: context)!
        super.init(entity: entity, insertInto: context)
        
        if let callID {
            self.callID = callID as NSNumber
        }
        if let date {
            self.date = date
        }
        
        self.contact = contactEntity
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
}
