//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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

import Foundation

public protocol ContactListFetchManager {
    var contactsResultController: NSFetchedResultsController<NSFetchRequestResult> { get }
    var groupsResultController: NSFetchedResultsController<NSFetchRequestResult> { get }
    var distributionListsResultController: NSFetchedResultsController<NSFetchRequestResult> { get }
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
    
    public var workContactsResultController: NSFetchedResultsController<NSFetchRequestResult> {
        contactsResultController.then {
            $0.fetchRequest.predicate = ContactFilterOption.onlyWork.predicate
        }
    }
    
    public var contactsResultController: NSFetchedResultsController<NSFetchRequestResult> {
        .init(
            fetchRequest: .init(entityName: "Contact").then {
                let sortOrderFirstName = UserSettings.shared().sortOrderFirstName
                $0.sortDescriptors = [
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

                $0.predicate = NSPredicate(format: "hidden == nil OR hidden == 0")
            },
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: "sortIndex",
            cacheName: nil
        )
    }
    
    public var groupsResultController: NSFetchedResultsController<NSFetchRequestResult> {
        .init(
            fetchRequest: .init(entityName: "Conversation").then {
                $0.fetchBatchSize = 100
                $0.sortDescriptors = [
                    NSSortDescriptor(key: "groupName", ascending: true),
                ]
                $0.predicate = NSPredicate(format: "groupId != nil", argumentArray: nil)
            },
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
    }
    
    public var distributionListsResultController: NSFetchedResultsController<NSFetchRequestResult> {
        .init(
            fetchRequest: .init(entityName: "DistributionList").then {
                $0.fetchBatchSize = 100
                $0.sortDescriptors = [
                    NSSortDescriptor(key: "name", ascending: true),
                ]
            },
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
    }
}
