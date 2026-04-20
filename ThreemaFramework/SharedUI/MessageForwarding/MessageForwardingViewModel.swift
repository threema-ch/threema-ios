import CocoaLumberjackSwift
import CoreData
import Observation
import ThreemaMacros

@MainActor @Observable
public final class MessageForwardingViewModel {

    // MARK: - Internal types

    enum Section: Hashable {
        case main
    }

    // MARK: - Public properties

    let cancelButtonTitle = #localize("cancel")
    let confirmationButtonTitle = #localize("send")
    let screenTitle = #localize("message_forwarding_screen_title")
    let message: BaseMessageEntity

    var isConfirmationButtonEnabled: Bool {
        !selectedItemIdentifiers.isEmpty
    }

    /// The item identifiers of the conversations in their order.
    private(set) var itemIdentifiers = [ItemID]()

    /// The selected conversation item identifiers in their order.
    ///
    /// This is an array instead of a set because the header carousel must keep
    /// the selection order stable. A set would reorder the items whenever the
    /// selection changes.
    private(set) var selectedItemIdentifiers = [ItemID]() {
        willSet {
            previouslySelectedItemIdentifiers = Set(selectedItemIdentifiers)
        }
    }

    /// A list of items that needs to be updated (reconfigured) to reflect their new selection state
    ///
    /// Contains:
    /// - Selected before, but are not selected now (they were deselected).
    /// - Not selected before, but are selected now (they were newly selected).
    /// - Everything is a subset of all item identifiers
    @ObservationIgnored
    var changedItemIdentifiers: [ItemID] {
        Array(
            Set(itemIdentifiers).intersection(
                previouslySelectedItemIdentifiers.symmetricDifference(selectedItemIdentifiers)
            )
        )
    }

    /// A flag that indicates if the forward message screen should be dismissed.
    private(set) var shouldDismiss = false

    // MARK: - Private properties

    private let distributionListManager: any DistributionListManagerProtocol
    private let entityFetcher: EntityFetcher
    private let entityManager: EntityManager
    private let forwarder = MessageForwarder()
    private let groupManager: any GroupManagerProtocol
    private let settingsStore: any SettingsStoreProtocol

    /// The previously selected conversation item identifiers before updating with search results new selection.
    @ObservationIgnored
    private(set) var previouslySelectedItemIdentifiers = Set<ItemID>()

    // MARK: - Lifecycle

    public init(businessInjector: any BusinessInjectorProtocol, message: BaseMessageEntity) {
        self.distributionListManager = businessInjector.distributionListManager
        self.entityFetcher = businessInjector.entityManager.entityFetcher
        self.entityManager = businessInjector.entityManager
        self.groupManager = businessInjector.groupManager
        self.message = message
        self.settingsStore = businessInjector.settingsStore
    }

    // MARK: - Public methods

    func viewWillAppear() {
        loadItems()
    }

    func selectableItem(for itemIdentifier: ItemID) -> SelectableItem? {
        let isSelected = isIdentifierSelected(itemIdentifier)

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
                let item = SelectableItem(id: itemIdentifier, item: .distributionList(list), isSelected: isSelected)
                return item
            }
            else {
                return nil
            }
        }
    }

    func selectableItemForSelectedIdentifier(at index: Int) -> SelectableItem? {
        guard index < selectedItemIdentifiers.count else {
            return nil
        }
        return selectableItem(for: selectedItemIdentifiers[index])
    }

    func selectableItemsForSelectedIdentifiers() -> [SelectableItem] {
        selectedItemIdentifiers.compactMap { selectableItem(for: $0) }
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

    func updateSelectedItemIdentifiers(_ newSelectedIdentifiers: [ItemID]) {
        let additional = newSelectedIdentifiers.filter { id in
            itemIdentifiers.contains(id) == false
        }

        itemIdentifiers += additional
        selectedItemIdentifiers = newSelectedIdentifiers
    }

    func handleConfirmationButtonTapped(sendAsFile: Bool, additionalContent: MessageForwarder.AdditionalContent?) {
        let conversationEntities = entityManager.performAndWait {
            self.selectedItemIdentifiers.compactMap {
                if let conversationEntity = self.entityFetcher.conversationEntity(with: $0) {
                    return conversationEntity
                }
                else if let contactEntity = self.entityFetcher.contactEntity(with: $0),
                        let conversationEntity = self.entityManager.conversation(
                            forContact: contactEntity,
                            createIfNotExisting: true
                        ) {
                    return conversationEntity
                }
                else {
                    let error = "Every selected item must be either a conversation or a contact"
                    assertionFailure("\(error)")
                    DDLogError("\(error)")
                    return nil
                }
            }
        }

        for conversationEntity in conversationEntities {
            forwarder.forward(
                message,
                to: conversationEntity,
                sendAsFile: sendAsFile,
                additionalContent: additionalContent
            )
        }
        shouldDismiss = true
    }

    // MARK: - Private Methods

    private func loadItems() {
        let excludePrivate = settingsStore.hidePrivateChats
        let ids = entityManager.performAndWait {
            self.entityFetcher.conversationOrContactIDs(excludeArchived: true, excludePrivate: excludePrivate)
        }
        itemIdentifiers = ids
    }
}
