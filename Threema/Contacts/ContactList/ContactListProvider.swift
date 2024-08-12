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

import ThreemaFramework

class ContactListProvider: CoreDataContactListProvider<ContactEntity, Contact> {
    init() {
        super.init(
            fetchedResultsController: BusinessInjector().entityManager.entityFetcher.contactsResultController
        ) { entity in
            Contact(contactEntity: entity)
        }
    }
}

class WorkContactListProvider: CoreDataContactListProvider<ContactEntity, Contact> {
    init() {
        super.init(
            fetchedResultsController: BusinessInjector().entityManager.entityFetcher.workContactsResultController
        ) { entity in
            Contact(contactEntity: entity)
        }
    }
}

class GroupListProvider: CoreDataContactListProvider<Conversation, Group> {
    init() {
        super.init(
            fetchedResultsController: BusinessInjector().entityManager.entityFetcher.groupsResultController
        ) { entity in
            BusinessInjector().groupManager.getGroup(conversation: entity)
        }
    }
}

// class DistributionListProvider: CoreDataContactListProvider<DistributionListEntity, DistributionListObject,
// GroupCell> {
//    init() {
//        super.init(
//            fetchedResultsController: BusinessInjector().entityManager.entityFetcher.fetchedResultsControllerForDistributionLists()
//        ) { entity in
//            DistributionListObject(distributionListEntity: entity)
//        }
//    }
// }
