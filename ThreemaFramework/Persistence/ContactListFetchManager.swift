//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

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
        ]
        
        var predicates: [NSPredicate] = [contactNotHiddenPredicate()]
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Contact")
        
        if hideStaleContacts {
            predicates.append(contactHideStalePredicate())
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
