//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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
import UIKit

final class DistributionListDetailsViewController: ThemedCodeModernGroupedTableViewController {

    // MARK: - Private properties
    
    // Mode to show view in
    private let displayMode: DistributionListDetailsDisplayMode
    private weak var delegate: DetailsDelegate?
    
    private lazy var headerView: DetailsHeaderView = {
        
        var actions = quickActions(in: self)
        
        if displayStyle == .preview {
            // Don't show quick actions in preview style
            actions = []
        }
        
        return DetailsHeaderView(
            with: distributionList.contentConfiguration,
            avatarImageTapped: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                guard let strongSelf = self else {
                    return
                }
                guard let distributionListProfilePictureData = strongSelf.distributionList.conversation?.groupImage?
                    .data,
                    let profilePicture = UIImage(data: distributionListProfilePictureData) else {
                    return
                }
                
                strongSelf.presentFullscreen(image: profilePicture)
            },
            quickActions: actions
        )
    }()
    
    private lazy var dataSource = DistributionListDetailsDataSource(
        for: distributionList,
        displayMode: displayMode,
        distributionListDetailsViewController: self,
        tableView: tableView
    )
    
    private let distributionList: DistributionListEntity
    
    // Display style of the chosen mode
    private let displayStyle: DetailsDisplayStyle
    
    private lazy var entityManager = EntityManager()
    
    private var observers = [NSKeyValueObservation]()
    
    // Backwards compatibility
    
    @available(*, deprecated, message: "Only use this for old code to keep it working")
    @objc var _distributionList: DistributionListEntity {
        distributionList
    }
    
    // MARK: - Lifecycle
    
    /// Show details of a distribution list
    /// - Parameters:
    ///   - distributionList: DistributionListEntity to show details for
    ///   - displayMode: Mode the distribution list is shown in
    ///   - displayStyle: Appearance of the distribution list details
    ///   - delegate: Details delegate that is called on certain actions. This should be set when `displayMode` is
    /// `conversation`.
    @objc init(
        for distributionList: DistributionListEntity,
        displayMode: DistributionListDetailsDisplayMode = .default,
        displayStyle: DetailsDisplayStyle = .default,
        delegate: DetailsDelegate? = nil
    ) {
        self.displayStyle = displayStyle
        self.delegate = delegate
        
        self.distributionList = distributionList
        
        self.displayMode = displayMode

        super.init()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureTableView()
        
        addObservers()
        
        configureHeader()
        dataSource.configureData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Call it here to ensure we have the correct constraints
        updateHeaderLayout(animated: false)
    }
    
    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        
        if parent == nil {
            removeObservers()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        delegate?.detailsDidDisappear()
    }
    
    deinit {
        DDLogDebug("\(#function)")
    }
    
    // MARK: - Configuration

    private func addObservers() {
        // Dynamic type
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferredContentSizeCategoryDidChange),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )

        // TODO: (IOS-4366) Add observers

//        observeGroup(\.name) { [weak self] in
//            self?.navigationBarTitle = self?.distributionList.name
//            self?.updateHeader(animated: false)
//        }
        
        observeGroup(\.willBeDeleted) {
            // will be handled in group object
        }
                
        observeGroup(\.profilePicture) { [weak self] in
            self?.updateHeader(animated: false)
        }

        // TODO: Observe each member and explicitly reload the cells that have a changed member
        // otherwise the diffable data source doesn't refresh the cell
        observeGroup(\.members) { [weak self] in
            self?.dataSource.reload(sections: [.recipients])
        }

//        observeGroup(\.state) { [weak self] in
//            guard let strongSelf = self else {
//                return
//            }
//            if !strongSelf.distributionList.willBeDeleted {
//                strongSelf.dataSource.reload(sections: [.members, .creator, .destructiveGroupActions])
//                strongSelf.updateHeader(animated: false)
//            }
//        }
    }
    
    private func removeObservers() {
        // Invalidate all observers
        for observer in observers {
            observer.invalidate()
        }
        
        // Remove them so we don't reference old observers
        observers.removeAll()
    }

    // TODO: (IOS-4366) Add observers
    /// Helper to add observers to the `group` property
    ///
    /// All observers are store in the `observers` property.
    ///
    /// - Parameters:
    ///   - keyPath: Key path in `Group` to observe
    ///   - changeHandler: Handler called on each observed change.
    ///                     Don't forget to capture `self` weakly! Dispatched on the main queue.
    private func observeGroup(
        _ keyPath: KeyPath<Group, some Any>,
        changeHandler: @escaping () -> Void
    ) {
//        let observer = group.observe(keyPath) { [weak self] _, _ in
//            guard let strongSelf = self else {
//                return
//            }
//
//            // Check if the observed group is in the process to be deleted
//            guard !strongSelf.group.willBeDeleted else {
//                // Invalidate and remove all observers
//                strongSelf.removeObservers()
//
//                // Hide myself
//                strongSelf.dismiss(animated: true)
//                strongSelf.navigationController?.popViewController(animated: true)
//
//                return
//            }
//
//            // It's important to call change handler on main thread, because Group object can update itself in the
//            // background
//            DispatchQueue.main.async {
//                changeHandler()
//            }
//        }
//
//        observers.append(observer)
    }

    // MARK: - Updates
    
    private func updateHeader(animated: Bool = true) {
        headerView.profileContentConfiguration = distributionList.contentConfiguration
        updateHeaderLayout(animated: animated)
    }

    // MARK: - Actions
    
    @objc private func editButtonTapped() {

        let editGroupViewController = DistributionListCreateEditViewController(distributionList: distributionList)
        let themedNavigationController = ThemedNavigationController(rootViewController: editGroupViewController)
        themedNavigationController.modalPresentationStyle = .formSheet

        present(themedNavigationController, animated: true)
    }
    
    @objc private func doneButtonTapped() {
        dismiss(animated: true)
    }
        
    // MARK: - Notifications
    
    @objc private func preferredContentSizeCategoryDidChange() {
        updateHeaderLayout()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if previousTraitCollection?.verticalSizeClass != traitCollection.verticalSizeClass {
            // This will be called on rotation
            updateHeaderLayout()
        }
    }
}

// MARK: - Table view

extension DistributionListDetailsViewController {
    private func configureTableView() {
        navigationBarTitle = String(distributionList.name)
        
        // If this is not set to `self` the automatic (dis)appearance of the navigation bar doesn't
        // work, because it is applied in the `UIScrollViewDelegate` in our superclass.
        tableView.delegate = self
        transparentNavigationBarWhenOnTop = true

        tableView.cellLayoutMarginsFollowReadableWidth = true
        
        dataSource.registerHeaderAndCells()
        dataSource.defaultRowAnimation = .fade
    }
}

// MARK: - Header & Quick Actions

extension DistributionListDetailsViewController {
    
    private func configureHeader() {
        configureNavigationBar()
        configureHeaderView()
    }
    
    private func configureNavigationBar() {
        navigationItem.largeTitleDisplayMode = .never
        
        let editBarButton = UIBarButtonItem(
            barButtonSystemItem: .edit,
            target: self,
            action: #selector(editButtonTapped)
        )
        
        // Check if we are presented in a modal view and we are the root vc of
        // the navigation controller
        if isPresentedInModalAndRootView {
            
            navigationItem.leftBarButtonItem = editBarButton

            // Only show done button when presented modally
            let doneButton = UIBarButtonItem(
                barButtonSystemItem: .done,
                target: self,
                action: #selector(doneButtonTapped)
            )
            doneButton.accessibilityIdentifier = "GroupDetailsViewControllerDoneButton"
            navigationItem.rightBarButtonItem = doneButton
        }
        else {
            // Left bar button is most likely a back button
            navigationItem.rightBarButtonItem = editBarButton
        }
    }
    
    private func configureHeaderView() {
        // Initial header configuration
        headerView.profileContentConfiguration = distributionList.contentConfiguration
        
        tableView.tableHeaderView = headerView
        
        // Header layout
        
        // Set the header top layout margin to the same as the bottom when in preview mode
        if displayStyle == .preview {
            let currentMargins = headerView.directionalLayoutMargins
            headerView.directionalLayoutMargins = NSDirectionalEdgeInsets(
                top: currentMargins.bottom,
                leading: currentMargins.leading,
                bottom: currentMargins.bottom,
                trailing: currentMargins.trailing
            )
        }
        
        headerView.translatesAutoresizingMaskIntoConstraints = false
        // To make these constraints work always call `updateHeaderLayout(animated:)` when the header
        // layout might have changed
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: tableView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: tableView.layoutMarginsGuide.leadingAnchor),
            headerView.bottomAnchor.constraint(equalTo: tableView.bottomAnchor),
            headerView.trailingAnchor.constraint(equalTo: tableView.layoutMarginsGuide.trailingAnchor),
        ])
    }
    
    // Always call when the header layout might have changed (e.g. rotation, dynamic type change)
    private func updateHeaderLayout(animated: Bool = true) {
        DispatchQueue.main.async {
            let updateHeight = {
                self.tableView.tableHeaderView = self.headerView
                self.headerView.layoutIfNeeded()
                self.tableView.layoutIfNeeded()
            }

            if animated {
                // Use table view update to animate height change
                // https://stackoverflow.com/a/32228700/286611
                UIView.animate(withDuration: 0.6) {
                    updateHeight()
                }
            }
            else {
                updateHeight()
            }
        }
    }
    
    /// Reload Quick Actions and header layout
    func reloadHeader() {
        headerView.reloadQuickActions()
        updateHeaderLayout()
    }
}

// MARK: - LegacyUIActionProvider

extension DistributionListDetailsViewController: LegacyUIActionProvider {
    func quickActions(in viewController: UIViewController) -> [QuickAction] {
        dataSource.quickActions(in: viewController)
    }
    
    @objc func uiActions(in viewController: UIViewController) -> NSArray {
        let actions = quickActions(in: viewController).map(\.asUIAction)
        return actions as NSArray
    }
}

// MARK: - Deleting messages

extension DistributionListDetailsViewController {
    func willDeleteMessages(with objectIDs: [NSManagedObjectID]) {
        delegate?.willDeleteMessages(with: objectIDs)
    }
    
    func willDeleteAllMessages() {
        delegate?.willDeleteAllMessages()
    }
}

// MARK: - UITableViewDelegate

// The delegate is here instead of `GroupDetailsDataSource`, because otherwise
// the `transparentNavigationBarWhenOnTop` using `UIScrollViewDelegate` would not work correctly.
extension DistributionListDetailsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let sectionIdentifiers = dataSource.snapshot().sectionIdentifiers
        
        // This should always be true, but just to be safe
        guard sectionIdentifiers.count > section else {
            return nil
        }
        
        let section = sectionIdentifiers[section]
        
        // Figure out title and maybe action
        
        var title: String?
        var action: Details.Action?
        
        switch section {

        case .recipients:
            let localizedFormatString = BundleUtil
                .localizedString(forKey: "distribution_list_recipients_section_header")
            title = String.localizedStringWithFormat(localizedFormatString, dataSource.numberOfRecipients)
            
        default:
            title = nil
        }
        
        // Only show section title if we have any title
        guard title != nil else {
            return nil
        }
        
        let headerView: DetailsSectionHeaderView? = tableView.dequeueHeaderFooter()
        headerView?.title = title
        headerView?.action = action
        
        return headerView
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let row = dataSource.itemIdentifier(for: indexPath) else {
            DDLogDebug("No item identifier found for \(indexPath)")
            return
        }
        
        switch row {
        
        case let .recipientsAction(action),
             let .action(action):
            guard let cell = tableView.cellForRow(at: indexPath) else {
                fatalError("We should have a cell that was tapped for an action.")
            }
            
            action.run(cell)
        
        case let .contact(contact, isSelfMember: _):
            
            let singleDetailsViewController = SingleDetailsViewController(for: contact)
            show(singleDetailsViewController, sender: self)
            
        case let .wallpaper(action: action, isDefault: _):
            guard let cell = tableView.cellForRow(at: indexPath) else {
                fatalError("We should have a cell that was tapped for an action.")
            }
            
            action.run(cell)
            
        default:
            // No action possible
            break
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - Peak & pop actions support

// Used for iOS 12 support
extension DistributionListDetailsViewController {
    override var previewActionItems: [UIPreviewActionItem] {
        guard let presentingViewController else {
            return []
        }
        
        // In theory the view controller where the peak interaction starts is what we
        // want there, but it also works with the presenting VC which is the
        // `MainTabBarController`.
        return quickActions(in: presentingViewController).map(\.asUIPreviewAction)
    }
}

extension DistributionListEntity {
    /// Get a content configuration base on this `DistributionList`
    fileprivate var contentConfiguration: DetailsHeaderProfileView.ContentConfiguration {
        DetailsHeaderProfileView.ContentConfiguration(
            avatarImageProvider: avatarImageProvider(completion:),
            name: String(name),
            isSelfMember: true
        )
    }
    
    private func avatarImageProvider(completion: @escaping (UIImage?) -> Void) {
        let entityManager = EntityManager()
        if let conversationEntity = conversation {
            AvatarMaker.shared().avatar(
                for: conversation,
                size: DetailsHeaderProfileView.avatarImageSize,
                masked: true
            ) { avatarImage, _ in
                DispatchQueue.main.async {
                    completion(avatarImage)
                }
            }
        }
    }
}
