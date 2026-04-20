import CocoaLumberjackSwift
import ThreemaFramework
import UIKit

protocol ContactListCellProviderProtocol<Cell, BusinessEntity> {
    typealias ContactListCellType = ThemedCodeTableViewCell & Reusable
    
    associatedtype Cell: ContactListCellType
    associatedtype BusinessEntity: NSObject
    
    func dequeueCell(
        for indexPath: IndexPath,
        and entity: BusinessEntity?,
        in tableView: UITableView
    ) -> Cell?
}

extension ContactListCellProviderProtocol {
    func registerCells(in tableView: UITableView) {
        tableView.registerCell(Cell.self)
    }
}

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

struct ContactListSelectionCellProvider: ContactListCellProviderProtocol {
    func dequeueCell(
        for indexPath: IndexPath,
        and contact: Contact?,
        in tableView: UITableView
    ) -> ContactCell? {
        guard let contact else {
            DDLogError("[ContactListSelectionCellProvider] Unable to load contact.")
            return tableView.dequeueCell(for: indexPath) as ContactCell
        }

        return (tableView.dequeueCell(for: indexPath) as ContactCell).then {
            $0.selectionStyle = .none
            $0.hasCheckmark = true
            $0.isSelected = false
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
