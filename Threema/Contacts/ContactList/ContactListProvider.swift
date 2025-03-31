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

import ThreemaFramework

class ContactListProvider: CoreDataContactListProvider<ContactEntity, Contact> {
    init() {
        super.init(at: \.contactsResultController) {
            Contact(contactEntity: $0)
        }
    }
}

class WorkContactListProvider: CoreDataContactListProvider<ContactEntity, Contact> {
    init() {
        super.init(at: \.workContactsResultController) {
            Contact(contactEntity: $0)
        }
    }
}

class GroupListProvider: CoreDataContactListProvider<ConversationEntity, Group> {
    init() {
        super.init(at: \.groupsResultController) {
            BusinessInjector.ui.groupManager.getGroup(conversation: $0)
        }
    }
}

class DistributionListProvider: CoreDataContactListProvider<DistributionListEntity, DistributionList> {
    init() {
        super.init(at: \.distributionListsResultController) {
            DistributionList(distributionListEntity: $0)
        }
    }
}
