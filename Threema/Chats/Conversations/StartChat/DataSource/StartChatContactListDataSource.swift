import Combine
import Foundation
import ThreemaFramework
import ThreemaMacros
import UIKit

typealias StartChatContactListSnapshot = NSDiffableDataSourceSnapshot<
    StartChatContactListDataSource.Section,
    StartChatContactListDataSource.Section.Row
>
final class StartChatContactListDataSource: UITableViewDiffableDataSource<
    StartChatContactListDataSource.Section,
    StartChatContactListDataSource.Section.Row
> {
    
    // MARK: - Types
    
    enum Section: Hashable {
        case actions
        case contacts(String)
        
        enum Row: Hashable {
            case addContact
            case addGroup
            case addDistributionList
            case contact(NSManagedObjectID)
        }
    }

    // MARK: - Properties

    /// When non-blank, the actions section is hidden and only contacts matching the text are shown (see
    /// `applyProviderSnapshot()`)
    var filterText = "" {
        didSet {
            // Treat blank text (empty or whitespace-only) as no filter, so the full list stays visible
            filterText = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard filterText != oldValue else {
                return
            }
            applyProviderSnapshot()
        }
    }
    
    var isSearching: Bool {
        !filterText.isEmpty
    }

    private let entityManager: EntityManager
    private var snapshotSubscription: Cancellable?
    private var providerSnapshot = ContactListProvider.ContactListSnapshot()
    private var sectionTitles: [String] { ThreemaLocalizedIndexedCollation.sectionIndexTitles }
    private var tableIndexTitles: [String?] {
        snapshot().sectionIdentifiers.map { section in
            switch section {
            case let .contacts(label):
                if let i = Int(label), i >= 0, i < sectionTitles.count {
                    sectionTitles[i]
                }
                else {
                    label
                }
            case .actions:
                nil
            }
        }
    }

    // MARK: - Lifecycle

    init(
        provider: ContactListProvider,
        cellProvider: ContactListCellProvider,
        entityManager: EntityManager,
        in tableView: UITableView,
    ) {
        self.entityManager = entityManager

        super.init(tableView: tableView) { tableView, indexPath, row in
            switch row {
            case let .contact(objectID):
                let contactEntity = entityManager.performAndWait {
                    entityManager.entityFetcher.existingObject(with: objectID) as? ContactEntity
                }
                guard let contactEntity else {
                    // TODO: (IOS-4536) Error
                    fatalError()
                }

                return cellProvider.dequeueCell(
                    for: indexPath,
                    and: Contact(contactEntity: contactEntity),
                    in: tableView
                )

            case .addContact:
                let cell = tableView
                    .dequeueReusableCell(withIdentifier: StartChatAddItemCell.reuseIdentifier) as! StartChatAddItemCell
                cell.configure(with: .contact)
                
                return cell
                
            case .addGroup:
                let cell = tableView
                    .dequeueReusableCell(withIdentifier: StartChatAddItemCell.reuseIdentifier) as! StartChatAddItemCell
                cell.configure(with: .group)
                
                return cell

            case .addDistributionList:
                let cell = tableView
                    .dequeueReusableCell(withIdentifier: StartChatAddItemCell.reuseIdentifier) as! StartChatAddItemCell
                cell.configure(with: .distributionList)
                
                return cell
            }
        }

        defaultRowAnimation = .fade

        registerCells(tableView, cellProvider: cellProvider)
        subscribe(to: provider)
    }

    deinit {
        snapshotSubscription?.cancel()
    }

    // MARK: - Overrides

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        tableIndexTitles[section]
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let kinds: [StartChatAddItemCell.AddItemKind] = [.contact, .group]
        // The actions section (and thus its footer) is hidden while searching
        guard !isSearching,
              section == 0,
              kinds.contains(where: { !$0.enabled }) else {
            return nil
        }
        return #localize("disabled_by_device_policy_feature")
    }

    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        sectionTitles
    }

    override func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        tableIndexTitles.firstIndex(of: title) ?? 0
    }

    private func subscribe(to provider: ContactListProvider) {
        snapshotSubscription = provider.currentSnapshot.sink { [weak self] contactSnapshot in
            guard let self else {
                return
            }
            providerSnapshot = contactSnapshot
            applyProviderSnapshot()
        }
    }

    private func applyProviderSnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Section.Row>()

        // The actions only show when not searching
        if !isSearching {
            snapshot.appendSections([.actions])
            snapshot.appendItems(
                [
                    .addContact,
                    .addGroup,
                    StartChatAddItemCell.AddItemKind.distributionList.enabled ? .addDistributionList : nil,
                ].compactMap(\.self),
                toSection: .actions
            )
        }

        let matchingIDs: Set<NSManagedObjectID>? =
            !isSearching
                ? nil
                : Set(
                    entityManager.entityFetcher.matchingContactsForContactListSearch(
                        containing: filterText,
                        hideStaleContacts: UserSettings.shared().hideStaleContacts
                    )
                )

        for sectionID in providerSnapshot.sectionIdentifiers {
            var items = providerSnapshot.itemIdentifiers(inSection: sectionID)
            if let matchingIDs {
                items = items.filter { matchingIDs.contains($0) }
            }

            guard !items.isEmpty else {
                continue
            }

            let section = Section.contacts(sectionID)
            snapshot.appendSections([section])
            snapshot.appendItems(items.map(Section.Row.contact), toSection: section)
        }

        apply(snapshot)
    }

    // MARK: - Helpers
    
    private func registerCells(_ tableView: UITableView, cellProvider: ContactListCellProvider) {
        cellProvider.registerCells(in: tableView)
        tableView.registerCell(StartChatAddItemCell.self)
    }
}
