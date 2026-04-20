import ThreemaFramework

final class ContactListProvider: CoreDataContactListProvider<ContactEntity, Contact> {
    init() {
        super.init(
            fetchedResultsController: BusinessInjector.ui.entityManager.entityFetcher
                .contactsResultController(
                    sortOrderFirstName: BusinessInjector.ui.userSettings.sortOrderFirstName,
                    hideStaleContacts: BusinessInjector.ui.userSettings.hideStaleContacts
                )
        ) {
            Contact(contactEntity: $0)
        }
    }
}

final class WorkContactListProvider: CoreDataContactListProvider<ContactEntity, Contact> {
    init() {
        super.init(
            fetchedResultsController: BusinessInjector.ui.entityManager.entityFetcher
                .workContactsResultController(
                    sortOrderFirstName: BusinessInjector.ui.userSettings.sortOrderFirstName,
                    hideStaleContacts: BusinessInjector.ui.userSettings.hideStaleContacts
                )
        ) {
            Contact(contactEntity: $0)
        }
    }
}

final class GroupListProvider: CoreDataContactListProvider<ConversationEntity, Group> {
    init() {
        super.init(fetchedResultsController: BusinessInjector.ui.entityManager.entityFetcher.groupsResultController()) {
            BusinessInjector.ui.groupManager.getGroup(conversation: $0)
        }
    }
}

final class DistributionListProvider: CoreDataContactListProvider<DistributionListEntity, DistributionList> {
    init() {
        super.init(
            fetchedResultsController: BusinessInjector.ui.entityManager.entityFetcher
                .distributionListsResultController()
        ) {
            DistributionList(distributionListEntity: $0)
        }
    }
}
