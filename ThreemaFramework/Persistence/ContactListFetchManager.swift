import CoreData
import Foundation

public protocol ContactListFetchManager {
    func workContactsResultController(sortOrderFirstName: Bool, hideStaleContacts: Bool)
        -> NSFetchedResultsController<NSFetchRequestResult>
    func contactsResultController(sortOrderFirstName: Bool, hideStaleContacts: Bool)
        -> NSFetchedResultsController<NSFetchRequestResult>
    func groupsResultController() -> NSFetchedResultsController<NSFetchRequestResult>
    func distributionListsResultController() -> NSFetchedResultsController<NSFetchRequestResult>
}

// MARK: - EntityFetcher + ContactListFetchManager

extension EntityFetcher: ContactListFetchManager {
    
    private enum ContactFilterOption {
        case onlyWork, noGateway, noEcho, gatewayOnly
        
        var predicate: NSPredicate {
            switch self {
            case .onlyWork:
                NSPredicate(format: "workContact == %@", NSNumber(value: 1))
            case .noGateway:
                NSPredicate(format: "not identity beginswith '*'")
            case .noEcho:
                NSPredicate(format: "not identity beginswith 'ECHOECHO'")
            case .gatewayOnly:
                NSPredicate(format: "identity beginswith '*'")
            }
        }
    }
    
    public func workContactsResultController(
        sortOrderFirstName: Bool,
        hideStaleContacts: Bool
    )
        -> NSFetchedResultsController<NSFetchRequestResult> {
        let contactsResultController = contactsResultController(
            sortOrderFirstName: sortOrderFirstName,
            hideStaleContacts: hideStaleContacts
        )
        
        var predicates: [NSPredicate] = [ContactFilterOption.onlyWork.predicate]
        if let predicate = contactsResultController.fetchRequest.predicate {
            predicates.append(predicate)
        }
           
        contactsResultController.fetchRequest
            .predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        return contactsResultController
    }
    
    public func contactsResultController(
        sortOrderFirstName: Bool,
        hideStaleContacts: Bool
    ) -> NSFetchedResultsController<NSFetchRequestResult> {
        let sortDescriptors: [NSSortDescriptor] = [
            NSSortDescriptor(key: "sortIndex", ascending: true),
            NSSortDescriptor(
                key: sortOrderFirstName ? "firstName" : "lastName",
                ascending: true,
                selector: #selector(NSString.localizedStandardCompare(_:))
            ),
            NSSortDescriptor(
                key: sortOrderFirstName ? "lastName" : "firstName",
                ascending: true,
                selector: #selector(NSString.localizedStandardCompare(_:))
            ),
            NSSortDescriptor(
                key: "publicNickname",
                ascending: true,
                selector: #selector(NSString.localizedStandardCompare(_:))
            ),
            NSSortDescriptor(
                key: "identity",
                ascending: true,
                selector: #selector(NSString.caseInsensitiveCompare(_:))
            ),
        ]
        
        var predicates: [NSPredicate] = [.contactIsVisible]
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Contact")
        
        if hideStaleContacts {
            predicates.append(.contactIsActive)
        }
        
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        fetchRequest.sortDescriptors = sortDescriptors
        
        return NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: "sortIndex",
            cacheName: nil
        )
    }
    
    public func groupsResultController() -> NSFetchedResultsController<NSFetchRequestResult> {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Conversation")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "groupName", ascending: true)]
        fetchRequest.fetchBatchSize = 100
        fetchRequest.predicate = NSPredicate(format: "groupId != nil", argumentArray: nil)
        
        return NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
    }
    
    public func distributionListsResultController() -> NSFetchedResultsController<NSFetchRequestResult> {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "DistributionList")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        fetchRequest.fetchBatchSize = 100
        
        return NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
    }
}
