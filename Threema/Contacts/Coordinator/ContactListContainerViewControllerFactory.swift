import UIKit

final class ContactListContainerViewControllerFactory {
    private let businessInjector: BusinessInjectorProtocol
    private let currentDestinationFetcher: () -> ContactListCoordinator.InternalDestination?
    private let shouldAllowAutoDeselection: () -> Bool
    
    init(
        businessInjector: BusinessInjectorProtocol,
        currentDestinationFetcher: @autoclosure @escaping () -> ContactListCoordinator.InternalDestination?,
        shouldAllowAutoDeselection: @autoclosure @escaping () -> Bool
    ) {
        self.businessInjector = businessInjector
        self.currentDestinationFetcher = currentDestinationFetcher
        self.shouldAllowAutoDeselection = shouldAllowAutoDeselection
    }
    
    func make(
        contactListActionDelegate: ContactListActionDelegate?,
        contactListSearchResultsDelegate: ContactListSearchResultsDelegate?
    ) -> ContactListContainerViewController {
        let currentDestinationFetcher = currentDestinationFetcher
        let shouldAllowAutoDeselection = shouldAllowAutoDeselection
        
        let myIdentityStore = businessInjector.myIdentityStore
        let entityManager = businessInjector.entityManager
        let entityFetcher = entityManager.entityFetcher
        let groupManager = businessInjector.groupManager
        let userSettings = businessInjector.userSettings
        
        return ContactListContainerViewController(
            contactListViewController: {
                ContactListViewController(
                    currentDestinationFetcher: currentDestinationFetcher,
                    shouldAllowAutoDeselection: shouldAllowAutoDeselection,
                    itemsDelegate: contactListActionDelegate
                )
            },
            groupListViewController: {
                GroupListViewController(
                    currentDestinationFetcher: currentDestinationFetcher,
                    shouldAllowAutoDeselection: shouldAllowAutoDeselection,
                    itemsDelegate: contactListActionDelegate
                )
            },
            distributionListViewController: {
                DistributionListViewController(
                    currentDestinationFetcher: currentDestinationFetcher,
                    shouldAllowAutoDeselection: shouldAllowAutoDeselection,
                    itemsDelegate: contactListActionDelegate
                )
            },
            workContactListViewController: {
                WorkContactListViewController(
                    currentDestinationFetcher: currentDestinationFetcher,
                    shouldAllowAutoDeselection: shouldAllowAutoDeselection,
                    itemsDelegate: contactListActionDelegate
                )
            },
            searchResultsController: {
                ContactListSearchResultsViewController(
                    delegate: contactListSearchResultsDelegate,
                    dataSourceFactory: { tableView in
                        ContactListSearchDataSource(
                            tableView: tableView,
                            fetchers: ContactListSearchDataSourceFetchers(
                                fetchContact: { objectID in
                                    entityManager.performAndWait { [entityManager] in
                                        entityManager.entityFetcher.existingObject(
                                            with: objectID
                                        ) as? ContactEntity
                                    }
                                },
                                fetchGroup: { objectID in
                                    entityManager.performAndWait { [entityFetcher, groupManager] in
                                        guard let conversation = entityFetcher.existingObject(
                                            with: objectID
                                        ) as? ConversationEntity else {
                                            return nil
                                        }
                                        
                                        return groupManager.getGroup(conversation: conversation)
                                    }
                                },
                                fetchDistributionList: { objectID in
                                    entityManager.performAndWait { [entityFetcher] in
                                        entityFetcher.existingObject(
                                            with: objectID
                                        ) as? DistributionListEntity
                                    }
                                },
                                fetchContactIDsForSearch: { searchText in
                                    let shouldHideStaleContacts = userSettings.hideStaleContacts
                                    return entityFetcher.matchingContactIDsForContactListSearch(
                                        containing: searchText,
                                        hideStaleContacts: shouldHideStaleContacts
                                    )
                                },
                                fetchConversationsForSearch: { searchText in
                                    entityFetcher.matchingConversationsForContactListSearch(
                                        containing: searchText
                                    )
                                },
                                fetchDistributionListIDsForSearch: { searchText in
                                    entityFetcher.matchingDistributionListsForContactListSearch(
                                        containing: searchText
                                    )
                                },
                                fetchDirectoryCategories: (myIdentityStore.directoryCategories as? [String: String]),
                                fetchCompanyName: myIdentityStore.companyName,
                                isCompanyDirectory: userSettings.companyDirectory,
                                isBusinessApp: TargetManager.isBusinessApp
                            ),
                            serverAPIConnectorFactory: ServerAPIConnector.init
                        )
                    },
                    onDirectoryContactAdded: {
                        NotificationPresenterWrapper.shared.present(type: .directoryContactAdded)
                    }
                )
            },
            navigationItem: ContactListNavigationItem(delegate: contactListActionDelegate)
        )
    }
}
