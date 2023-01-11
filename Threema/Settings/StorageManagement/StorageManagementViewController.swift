//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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
import PromiseKit
import UIKit

final class StorageManagementViewController: ThemedCodeModernGroupedTableViewController {

    // MARK: - Private types
    
    private let businessInjector = BusinessInjector()

    private enum Section: Hashable {
        case storage
        case manageAllData
        case deleteMessages
        case conversations
    }
    
    private enum Row: Hashable {
        case storage(label: String, type: ThreemaStorageSMTableViewCell.StorageType)
        case manageAllConversations
        case conversation(conversation: Conversation, businessInjector: BusinessInjector)
    }
    
    /// Simple subclass to provide easy header and footer string configuration
    private class DataSource: UITableViewDiffableDataSource<Section, Row> {
        typealias SupplementaryProvider = (UITableView, Section) -> String?
        
        let headerProvider: SupplementaryProvider
        let footerProvider: SupplementaryProvider
        
        init(
            tableView: UITableView,
            cellProvider: @escaping UITableViewDiffableDataSource<Section, Row>.CellProvider,
            headerProvider: @escaping SupplementaryProvider,
            footerProvider: @escaping SupplementaryProvider
        ) {
            self.headerProvider = headerProvider
            self.footerProvider = footerProvider
            
            super.init(tableView: tableView, cellProvider: cellProvider)
        }
        
        @available(*, unavailable)
        override init(
            tableView: UITableView,
            cellProvider: @escaping UITableViewDiffableDataSource<Section, Row>.CellProvider
        ) {
            fatalError("Not supported.")
        }
        
        override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
            let section = snapshot().sectionIdentifiers[section]
            return headerProvider(tableView, section)
        }
        
        override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
            let section = snapshot().sectionIdentifiers[section]
            return footerProvider(tableView, section)
        }
    }
        
    // MARK: - Properties
    
    private lazy var dataSource = DataSource(
        tableView: tableView,
        cellProvider: { [weak self] tableView, indexPath, row -> UITableViewCell? in
            guard let strongSelf = self else {
                return nil
            }
            
            switch row {
            case let .storage(label: label, type: type):
                let cell: ThreemaStorageSMTableViewCell = tableView.dequeueCell(for: indexPath)
                cell.label = label
                cell.storageType = type
                return cell
            case .manageAllConversations:
                let cell: ManageAllConversationsSMTableViewCell = tableView.dequeueCell(for: indexPath)
                return cell
            case let .conversation(conversation: conversation, businessInjector: businessInjector):
                let cell: ConversationOverviewSMTableViewCell = tableView.dequeueCell(for: indexPath)
                cell.setupConversation(conversation, businessInjector: businessInjector)
                return cell
            }
        },
        headerProvider: { [weak self] _, _ -> String? in
            guard let strongSelf = self else {
                return nil
            }
        
            return nil
        
        },
        footerProvider: { [weak self] _, section -> String? in
            guard let strongSelf = self else {
                return nil
            }
        
            switch section {
            default:
                return nil
            }
        }
    )
    
    private var mediaOlderThanOption = OlderThanOption.oneYear
    private var messageOlderThanOption = OlderThanOption.oneYear
    
    enum OlderThanOption: Int, CaseIterable {
        case oneYear = 0
        case sixMonths
        case threeMonths
        case oneMonth
        case oneWeek
        case everything
    }
        
    // MARK: - Lifecycle
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureNavigationBar()
        configureTableView()
        registerCells()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateContent()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
}
    
// MARK: - Configuration

extension StorageManagementViewController {
    
    private func configureNavigationBar() {
        navigationItem.largeTitleDisplayMode = .never
        
        navigationBarTitle = BundleUtil.localizedString(forKey: "storage_management")
    }
    
    private func configureTableView() {
        tableView.delegate = self
    }
    
    private func registerCells() {
        tableView.registerCell(ThreemaStorageSMTableViewCell.self)
        tableView.registerCell(ManageAllConversationsSMTableViewCell.self)
        tableView.registerCell(ConversationOverviewSMTableViewCell.self)
    }
}

// MARK: - Updates

extension StorageManagementViewController {
    
    private func updateContent() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Row>()
        
        snapshot.appendSections([.storage])
        snapshot.appendItems([.storage(label: BundleUtil.localizedString(forKey: "storage_total"), type: .total)])
        snapshot
            .appendItems([.storage(
                label: BundleUtil.localizedString(forKey: "storage_total_in_use"),
                type: .totalInUse
            )])
        snapshot
            .appendItems([.storage(label: BundleUtil.localizedString(forKey: "storage_total_free"), type: .totalFree)])
        snapshot.appendItems([.storage(label: String(
            format: BundleUtil.localizedString(forKey: "storage_threema"),
            ThreemaApp.currentName
        ), type: .threema)])
        
        snapshot.appendSections([.manageAllData])
        snapshot.appendItems([.manageAllConversations])
        
        snapshot.appendSections([.conversations])
        
        if let allConversations = businessInjector.entityManager.entityFetcher.allConversations() as? [Conversation] {
            let sorted = allConversations.sorted {
                let messageFetcher0 = MessageFetcher(for: $0, with: businessInjector.entityManager)
                let messageFetcher1 = MessageFetcher(for: $1, with: businessInjector.entityManager)
                return messageFetcher0.count() > messageFetcher1.count()
            }
            
            for conversation in sorted {
                snapshot.appendItems([.conversation(conversation: conversation, businessInjector: businessInjector)])
            }
            dataSource.apply(snapshot)
        }
    }
}

// MARK: - UITableViewDelegate

extension StorageManagementViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        guard let row = dataSource.itemIdentifier(for: indexPath) else {
            return nil
        }
        
        switch row {
        case .manageAllConversations, .conversation(conversation: _, businessInjector: _):
            return indexPath
        default:
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let row = dataSource.itemIdentifier(for: indexPath) else {
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }
        
        if case let .conversation(conversation: conversation, businessInjector: businessInjector) = row {
            let storageManagementConversationViewController = StorageManagementConversationViewController(
                conversation: conversation,
                businessInjector: businessInjector
            )
            self.navigationController?.pushViewController(storageManagementConversationViewController, animated: true)
        }
        if case .manageAllConversations = row {
            let storageManagementConversationViewController = StorageManagementConversationViewController()
            self.navigationController?.pushViewController(storageManagementConversationViewController, animated: true)
        }
    }
}
