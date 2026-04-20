import Observation
import ThreemaMacros

@MainActor @Observable
public final class RecipientSearchResultsViewModel {

    // MARK: - Internal types

    /// The sections used to group search results item identifiers.
    enum Section: Hashable, CaseIterable {
        case contacts
        case groups
        case distributionLists

        var title: String {
            switch self {
            case .contacts:
                #localize("contact_list_search_token_title_contacts")
            case .groups:
                #localize("contact_list_search_token_title_groups")
            case .distributionLists:
                #localize("contact_list_search_token_title_distribution_lists")
            }
        }
    }

    /// A data structure containing the search result item identifiers for each section
    struct GroupedSearchResultItemIdentifiers {
        let contactIDs: [ItemID]
        let groupIDs: [ItemID]
        let distributionListIDs: [ItemID]

        init(
            contactIDs: [ItemID] = [],
            groupIDs: [ItemID] = [],
            distributionListIDs: [ItemID] = []
        ) {
            self.contactIDs = contactIDs
            self.groupIDs = groupIDs
            self.distributionListIDs = distributionListIDs
        }
    }

    // MARK: - Internal properties

    /// The search result item identifiers in their order.
    private(set) var searchResultItemIdentifiers = GroupedSearchResultItemIdentifiers() {
        willSet {
            previouslySelectedItemIdentifiers = Set(selectedItemIdentifiers)
        }
    }

    /// The selected search result item identifiers in their order.
    ///
    /// The array will contain contact IDs, conversation IDs (groups) and distribution list IDs.
    /// It will not contain group IDs, since groups are assimilated to conversations.
    @ObservationIgnored
    private(set) var selectedItemIdentifiers = [ItemID]()

    /// A list of items that needs to be updated (reconfigured) to reflect their new selection state
    ///
    /// Contains:
    /// - Selected before, but are not selected now (they were deselected).
    /// - Not selected before, but are selected now (they were newly selected).
    var changedItemIdentifiers: [ItemID] {
        Array(
            previouslySelectedItemIdentifiers.symmetricDifference(selectedItemIdentifiers)
        )
    }

    // MARK: - Private properties

    private let distributionListManager: any DistributionListManagerProtocol
    private let entityFetcher: EntityFetcher
    private let entityManager: EntityManager
    private let groupManager: any GroupManagerProtocol
    private let settingsStore: any SettingsStoreProtocol

    /// The previously selected search result item identifiers
    @ObservationIgnored
    private var previouslySelectedItemIdentifiers = Set<ItemID>()

    // MARK: - Lifecycle

    public init(businessInjector: any BusinessInjectorProtocol) {
        self.distributionListManager = businessInjector.distributionListManager
        self.entityFetcher = businessInjector.entityManager.entityFetcher
        self.entityManager = businessInjector.entityManager
        self.groupManager = businessInjector.groupManager
        self.settingsStore = businessInjector.settingsStore
    }

    // MARK: - Internal methods

    func updateSelectedItemIdentifiers(_ itemIdentifiers: [ItemID]) {
        selectedItemIdentifiers = itemIdentifiers
    }

    func updateSearchResults(for query: String?) {
        guard let query, !query.isEmpty else {
            searchResultItemIdentifiers = GroupedSearchResultItemIdentifiers()
            return
        }
        let contactIDs = contactResultObjectIDs(query)
        let conversationIDsForGroups = conversationResultObjectIDsForGroups(query)
        let conversationIDsForDistributionLists = conversationResultObjectIDsForDistributionLists(query)
        searchResultItemIdentifiers = GroupedSearchResultItemIdentifiers(
            contactIDs: contactIDs,
            groupIDs: conversationIDsForGroups,
            distributionListIDs: conversationIDsForDistributionLists
        )
    }

    func items(for section: Section) -> [ItemID] {
        switch section {
        case .contacts:
            searchResultItemIdentifiers.contactIDs
        case .groups:
            searchResultItemIdentifiers.groupIDs
        case .distributionLists:
            searchResultItemIdentifiers.distributionListIDs
        }
    }

    func selectItem(with itemIdentifier: ItemID) {
        selectedItemIdentifiers.append(itemIdentifier)
    }

    func deselectItem(with itemIdentifier: ItemID) {
        selectedItemIdentifiers.removeAll { $0 == itemIdentifier }
    }

    func isIdentifierSelected(_ itemIdentifier: ItemID) -> Bool {
        selectedItemIdentifiers.contains(itemIdentifier)
    }

    func selectableItem(for itemIdentifier: ItemID) -> SelectableItem? {
        let isSelected = selectedItemIdentifiers.contains(itemIdentifier)

        if let contactEntity = entityFetcher.contactEntity(with: itemIdentifier) {
            let contact = Contact(contactEntity: contactEntity)
            let item = SelectableItem(id: itemIdentifier, item: .contact(contact), isSelected: isSelected)
            return item
        }
        else {
            guard let conversationEntity = entityFetcher.conversationEntity(with: itemIdentifier) else {
                return nil
            }
            if conversationEntity.isGroup, let group = groupManager.getGroup(conversation: conversationEntity) {
                let item = SelectableItem(id: itemIdentifier, item: .group(group), isSelected: isSelected)
                return item
            }
            else if let list = distributionListManager.distributionList(for: conversationEntity) {
                let item = SelectableItem(
                    id: itemIdentifier,
                    item: .distributionList(list),
                    isSelected: isSelected
                )
                return item
            }
            else {
                return nil
            }
        }
    }

    // MARK: - Private Methods

    private func contactResultObjectIDs(_ query: String) -> [NSManagedObjectID] {
        entityManager.performAndWait {
            let contactIDs = self.entityFetcher.matchingContactsForContactListSearch(
                containing: query,
                hideStaleContacts: self.settingsStore.hideStaleContacts
            )
            return contactIDs
        }
    }

    private func conversationResultObjectIDsForGroups(_ query: String) -> [NSManagedObjectID] {
        entityManager.performAndWait {
            let conversations = self.entityFetcher.filteredGroupConversationEntities(
                by: [query], excludePrivate: self.settingsStore.hidePrivateChats
            )
            let conversationObjectIDs = conversations.map(\.objectID)
            return conversationObjectIDs
        }
    }

    private func conversationResultObjectIDsForDistributionLists(_ query: String) -> [NSManagedObjectID] {
        entityManager.performAndWait {
            let distributionLists = self.entityFetcher.filteredDistributionListEntities(
                by: [query], excludePrivate: self.settingsStore.hidePrivateChats
            )
            let conversationObjectIDs = distributionLists.map(\.conversation.objectID)
            return conversationObjectIDs
        }
    }
}
