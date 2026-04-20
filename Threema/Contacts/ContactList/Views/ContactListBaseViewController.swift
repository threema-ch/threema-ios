import CocoaLumberjackSwift
import Foundation
import ThreemaFramework
import ThreemaMacros

class ContactListBaseViewController: ThemedTableViewController {
    
    // MARK: - Properties
    
    private let currentDestinationFetcher: () -> ContactListCoordinator.InternalDestination?
    private let shouldAllowAutoDeselection: () -> Bool
    weak var itemsDelegate: ContactListActionDelegate?
    let businessInjector: BusinessInjectorProtocol
    
    // MARK: - Lifecycle
    
    init(
        currentDestinationFetcher: @escaping () -> ContactListCoordinator.InternalDestination?,
        shouldAllowAutoDeselection: @escaping () -> Bool,
        businessInjector: BusinessInjectorProtocol = BusinessInjector.ui,
        itemsDelegate: ContactListActionDelegate? = nil
    ) {
        self.currentDestinationFetcher = currentDestinationFetcher
        self.shouldAllowAutoDeselection = shouldAllowAutoDeselection
        self.businessInjector = businessInjector
        self.itemsDelegate = itemsDelegate
        super.init(nibName: nil, bundle: nil)
        
        // This fixes the inset for the footer
        additionalSafeAreaInsets.bottom = 0
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureRefreshControl()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // This fixes transparency issues with the navigation bar
        tableView.setContentOffset(CGPoint(x: 0, y: -tableView.adjustedContentInset.top + 2), animated: true)
    }
    
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        
        updateSelection()
    }
    
    // MARK: - Updates
    
    func updateSelection() {
        if shouldAllowAutoDeselection() {
            tableView?.indexPathsForSelectedRows?.forEach {
                tableView?.deselectRow(at: $0, animated: false)
            }
        }
        else {
            guard let destination = currentDestinationFetcher(),
                  case let .contact(objectID) = destination,
                  let objectID,
                  let dataSource = tableView.dataSource as? UITableViewDiffableDataSource<
                      String,
                      NSManagedObjectID
                  >,
                  let indexPath = dataSource.indexPath(for: objectID) else {
                return
            }

            tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
        }
    }
    
    // MARK: - Pull to refresh
    
    private func configureRefreshControl() {
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(startPullToRefresh), for: .valueChanged)
        tableView.refreshControl = control
    }
    
    @objc private func startPullToRefresh() {
        tableView.refreshControl?.isUserInteractionEnabled = false
        syncContacts()
    }
    
    private func endPullToRefresh() {
        tableView.refreshControl?.isUserInteractionEnabled = true
        tableView.refreshControl?.endRefreshing()
    }
    
    // TODO: (IOS-4425) Some logic below should be in ContactStore and needs major clean-up
    func syncContacts() {
        GatewayAvatarMaker().refreshForced()
        
        let contactStore = businessInjector.contactStore
        
        guard businessInjector.userSettings.syncContacts else {
            if TargetManager.isBusinessApp {
                contactStore.synchronizeAddressBook(forceFullSync: true, ignoreMinimumInterval: true) { [weak self] _ in
                    self?.updateWorkData()
                } onError: { [weak self] _ in
                    self?.updateWorkData()
                }
            }
            else {
                NotificationPresenterWrapper.shared.present(type: .contactSyncOffWarning)
                endPullToRefresh()
            }
            return
        }
        
        contactStore.synchronizeAddressBook(forceFullSync: true, ignoreMinimumInterval: true) { [weak self] granted in
            
            guard let self else {
                return
            }
            
            if !granted {
                UIAlertTemplate.showOpenSettingsAlert(
                    owner: self,
                    noAccessAlertType: .contacts,
                    openSettingsCompletion: nil
                )
            }
            
            if TargetManager.isBusinessApp {
                updateWorkData()
            }
            else {
                endPullToRefresh()
                if granted {
                    NotificationPresenterWrapper.shared.present(type: .contactSyncSuccess)
                }
            }
            
        } onError: { error in
            if let nsError = error as? NSError, nsError.code == 429, TargetManager.isBusinessApp {
                UIAlertTemplate
                    .showAlert(
                        owner: self,
                        title: nil,
                        message: TargetManager
                            .isBusinessApp ? #localize("pull_to_sync_429_message_work") :
                            #localize("pull_to_sync_429_message")
                    )
                self.endPullToRefresh()
            }
            else {
                if TargetManager.isBusinessApp {
                    self.updateWorkData()
                }
                else {
                    NotificationPresenterWrapper.shared.present(type: .contactSyncFailed)
                    self.endPullToRefresh()
                }
            }
            DDLogError("[ContactList] Address book sync failed: \(error?.localizedDescription ?? "nil")")
        }
    }
    
    private func updateWorkData() {
        WorkDataFetcher.checkUpdateWorkDataForce(true, sendForce: true) { [weak self] in
            NotificationPresenterWrapper.shared.present(type: .contactSyncSuccess)
            self?.endPullToRefresh()
        } onError: { [weak self] error in
            guard let self else {
                return
            }
            
            if let nsError = error as? NSError, nsError.code == 401 || nsError.code == 409 {
                UIAlertTemplate
                    .showAlert(
                        owner: self,
                        title: nil,
                        message: #localize("pull_to_sync_429_message_work")
                    ) { _ in
                        NotificationPresenterWrapper.shared.present(type: .updateWorkDataFailed)
                    }
            }
            else {
                NotificationPresenterWrapper.shared.present(type: .workSyncFailed)
            }
            endPullToRefresh()
            DDLogError("[ContactList] Update work data failed: \(error?.localizedDescription ?? "nil")")
        }
    }
}
