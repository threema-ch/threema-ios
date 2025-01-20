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

import CocoaLumberjackSwift
import ThreemaFramework
import UIKit

struct ContactListCellProvider: ContactListCellProviderProtocol {
    func dequeueCell(
        for indexPath: IndexPath,
        and contact: Contact?,
        in tableView: UITableView
    ) -> ContactCell? {
        guard let contact else {
            DDLogError("Unable to load contact")
            return tableView.dequeueCell(for: indexPath) as ContactCell
        }

        return (tableView.dequeueCell(for: indexPath) as ContactCell).then {
            $0.content = .contact(contact)
        }
    }
}

struct GroupListCellProvider: ContactListCellProviderProtocol {
    func dequeueCell(
        for indexPath: IndexPath,
        and group: Group?,
        in tableView: UITableView
    ) -> GroupCell? {
        guard let group else {
            DDLogError("Unable to load group")
            return tableView.dequeueCell(for: indexPath) as GroupCell
        }

        return (tableView.dequeueCell(for: indexPath) as GroupCell).then {
            $0.group = group
        }
    }
}

struct DistributionListCellProvider: ContactListCellProviderProtocol {
    func dequeueCell(
        for indexPath: IndexPath,
        and distributionList: DistributionList?,
        in tableView: UITableView
    ) -> DistributionListCell? {
        guard let distributionList else {
            DDLogError("Unable to load distributionList")
            return tableView.dequeueCell(for: indexPath) as DistributionListCell
        }

        return (tableView.dequeueCell(for: indexPath) as DistributionListCell).then {
            $0.distributionList = distributionList
        }
    }
}
