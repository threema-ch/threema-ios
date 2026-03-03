//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

extension EntityFetcher {
    
    // MARK: - Contacts
    
    @objc public enum ContactType: Int {
        case all, noGateway, onlyGateway, noEchoEcho, noGatewayNoEchoEcho
    }
    
    @objc public enum ListType: Int {
        case contacts, work, contactsAndWork
    }
    
    @available(swift, obsoleted: 1.0, message: "Deprecated. Do not use anymore.")
    @objc public func fetchedResultsController(
        for type: ContactType,
        of list: ListType,
        with members: Set<ContactEntity>?,
        hideStaleContacts: Bool,
        sortOrderFirstName: Bool,
        isBusinessApp: Bool
    ) -> NSFetchedResultsController<NSFetchRequestResult> {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Contact")
        fetchRequest.fetchBatchSize = 100
        
        var predicates = [NSPredicate]()
        
        if let members {
            let ids = members.map(\.identity)
            let predicate = NSPredicate(
                format: "(hidden == nil OR hidden == 0) OR (hidden == 1 AND identity IN %@)",
                ids
            )
            predicates.append(predicate)
        }
        else {
            let predicate = NSPredicate(format: "hidden == nil OR hidden == 0")
            predicates.append(predicate)
        }
        
        switch type {
        case .all:
            break
        case .noGateway:
            let predicate = NSPredicate(format: "not identity beginswith '*'")
            predicates.append(predicate)
        case .onlyGateway:
            let predicate = NSPredicate(format: "identity beginswith '*'")
            predicates.append(predicate)
        case .noEchoEcho:
            let predicate = NSPredicate(format: "not identity beginswith 'ECHOECHO'")
            predicates.append(predicate)
        case .noGatewayNoEchoEcho:
            let echoPredicate = NSPredicate(format: "not identity beginswith 'ECHOECHO'")
            predicates.append(echoPredicate)
            let gatewayPredicate = NSPredicate(format: "not identity beginswith '*'")
            predicates.append(gatewayPredicate)
        }
        
        if hideStaleContacts {
            let predicate = NSPredicate(format: "state == %d", ContactEntity.ContactState.active.rawValue)
            predicates.append(predicate)
        }
        
        if list == .work {
            let predicate = NSPredicate(format: "workContact == %@", NSNumber(booleanLiteral: true))
            predicates.append(predicate)
        }
        else {
            if list == .contactsAndWork {
                // do not predicate for work contacts
            }
            else if isBusinessApp {
                let predicate = NSPredicate(format: "workContact == %@", NSNumber(booleanLiteral: false))
                predicates.append(predicate)
            }
        }
        
        var allPredicates = [NSCompoundPredicate(andPredicateWithSubpredicates: predicates) as NSPredicate]
        
        if hideStaleContacts, let members, !members.isEmpty {
            for member in members {
                let predicate = NSPredicate(format: "identity == %@", member.identity)
                allPredicates.append(predicate)
            }
        }
        
        let finalPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: allPredicates)
        fetchRequest.predicate = finalPredicate
        
        let sortDescriptors = nameSortDescriptors(sortOrderFirstName: sortOrderFirstName)
        fetchRequest.sortDescriptors = sortDescriptors
        
        let fetchedResultController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: "sortIndex",
            cacheName: nil
        )
        
        return fetchedResultController
    }
    
    func nameSortDescriptors(sortOrderFirstName: Bool) -> [NSSortDescriptor] {
        let sortIndex = NSSortDescriptor(key: "sortIndex", ascending: true)
        let firstName = NSSortDescriptor(
            key: "firstName",
            ascending: true,
            selector: #selector(NSString.localizedStandardCompare(_:))
        )
        let lastName = NSSortDescriptor(
            key: "lastName",
            ascending: true,
            selector: #selector(NSString.localizedStandardCompare(_:))
        )
        let publicNickname = NSSortDescriptor(
            key: "publicNickname",
            ascending: true,
            selector: #selector(NSString.localizedStandardCompare(_:))
        )
        
        if sortOrderFirstName {
            return [sortIndex, firstName, lastName, publicNickname]
        }
        else {
            return [sortIndex, lastName, firstName, publicNickname]
        }
    }
    
    // MARK: - DistributionLists
    
    @available(swift, obsoleted: 1.0, message: "Deprecated. Do not use anymore.")
    @objc public func fetchedResultsControllerForDistributionListEntities()
        -> NSFetchedResultsController<NSFetchRequestResult> {
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "DistributionList")
        fetchRequest.fetchBatchSize = 20
        
        let sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        fetchRequest.sortDescriptors = sortDescriptors
        
        let fetchedResultController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        return fetchedResultController
    }
    
    // MARK: - Group conversations

    @available(swift, obsoleted: 1.0, message: "Deprecated. Do not use anymore.")
    @objc public func fetchedResultsControllerForGroupConversationEntities()
        -> NSFetchedResultsController<NSFetchRequestResult> {
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Conversation")
        fetchRequest.predicate = NSPredicate(format: "groupId != nil")
        fetchRequest.fetchBatchSize = 20
        
        let sortDescriptors = [NSSortDescriptor(key: "groupName", ascending: true)]
        fetchRequest.sortDescriptors = sortDescriptors
        
        let fetchedResultController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        return fetchedResultController
    }
    
    // MARK: - Conversations
    
    @available(*, deprecated, message: "Deprecated. Do not use anymore.")
    @objc public func fetchedResultsControllerForConversationEntities(hidePrivateChats: Bool)
        -> NSFetchedResultsController<NSFetchRequestResult> {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Conversation")
        fetchRequest.relationshipKeyPathsForPrefetching = ["members"]
        fetchRequest.fetchBatchSize = 20
        
        var predicates = [NSPredicate]()
        predicates.append(conversationNotArchivedPredicate())
        predicates.append(conversationsWithLastUpdatePredicate())
        
        if hidePrivateChats {
            predicates.append(conversationNotPrivatePredicate())
        }
        
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        let visibilityDescriptor = NSSortDescriptor(key: "visibility", ascending: false)
        let lastUpdateDescriptor = NSSortDescriptor(key: "lastUpdate", ascending: false)
        let lastMessageDescriptor = NSSortDescriptor(key: "lastMessage.date", ascending: false)
        fetchRequest.sortDescriptors = [visibilityDescriptor, lastUpdateDescriptor, lastMessageDescriptor]
        
        let fetchedResultController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        return fetchedResultController
    }
    
    @available(*, deprecated, message: "Deprecated. Do not use anymore.")
    @objc public func fetchedResultsControllerForArchivedConversationEntities(hidePrivateChats: Bool)
        -> NSFetchedResultsController<NSFetchRequestResult> {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Conversation")
        fetchRequest.relationshipKeyPathsForPrefetching = ["members"]
        fetchRequest.fetchBatchSize = 20
        
        var predicates = [NSPredicate]()
        predicates.append(conversationArchivedPredicate())
        predicates.append(conversationsWithLastUpdatePredicate())
        
        if hidePrivateChats {
            predicates.append(conversationNotPrivatePredicate())
        }
        
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        let visibilityDescriptor = NSSortDescriptor(key: "visibility", ascending: false)
        let lastUpdateDescriptor = NSSortDescriptor(key: "lastUpdate", ascending: false)
        let lastMessageDescriptor = NSSortDescriptor(key: "lastMessage.date", ascending: false)
        fetchRequest.sortDescriptors = [visibilityDescriptor, lastUpdateDescriptor, lastMessageDescriptor]
        
        let fetchedResultController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        return fetchedResultController
    }
    
    @available(*, deprecated, message: "Deprecated. Do not use anymore.")
    public func fetchedResultsControllerForWebClientSessionEntities()
        -> NSFetchedResultsController<NSFetchRequestResult> {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "WebClientSession")
        fetchRequest.fetchBatchSize = 20
        
        let activeDescriptor = NSSortDescriptor(key: "active", ascending: false)
        let lastConnectionDescriptor = NSSortDescriptor(key: "lastConnection", ascending: false)

        fetchRequest.sortDescriptors = [activeDescriptor, lastConnectionDescriptor]
        
        let fetchedResultController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        return fetchedResultController
    }
    
    // MARK: - General
    
    @available(swift, obsoleted: 1.0, message: "Deprecated. Do not use anymore.")
    @objc public func fetchRequest(for entityName: String) -> NSFetchRequest<NSFetchRequestResult> {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        return fetchRequest
    }
}
