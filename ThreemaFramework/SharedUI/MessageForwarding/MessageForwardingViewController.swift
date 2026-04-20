import Observation
import SwiftUI
import ThreemaMacros
import TipKit
import UIKit

public final class MessageForwardingViewController: ThemedViewController {

    // MARK: - Private types and type aliases

    private typealias Section = MessageForwardingViewModel.Section
    private typealias DataSource = UITableViewDiffableDataSource<Section, ItemID>
    private typealias DataSourceSnapshot = NSDiffableDataSourceSnapshot<Section, ItemID>

    // MARK: - Private properties

    private let model: MessageForwardingViewModel
    private let messageInputModel: MessageForwardingBottomViewModel
    private let searchResultsViewController: RecipientSearchResultsViewController
    private let tip = TipKitManager.ThreemaForwardingCaptionInfoTip()
    private var tipObservation: Task<Void, Never>?
    private var tipPopoverController: TipUIPopoverViewController?

    private lazy var carouselView: SelectedItemsHeaderView = {
        let headerView = SelectedItemsHeaderView(collectionKind: .none)
        headerView.setContentHuggingPriority(.required, for: .vertical)
        headerView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.delegate = self

        return headerView
    }()

    private lazy var contentView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.distribution = .fill
        stackView.backgroundColor = .systemGroupedBackground
        return stackView
    }()

    private lazy var dataSource = DataSource(tableView: tableView, cellProvider: cellProvider)

    private lazy var searchController: UISearchController = {
        let controller = UISearchController(searchResultsController: searchResultsViewController)
        controller.delegate = self
        controller.hidesNavigationBarDuringPresentation = true
        controller.searchResultsUpdater = self
        controller.searchBar.placeholder = #localize("contact_list_search_bar_placeholder")
        controller.searchBar.setValue(#localize("Done"), forKey: "cancelButtonText")
        controller.searchBar.autocapitalizationType = .none
        controller.searchBar.autocorrectionType = .no
        controller.searchBar.spellCheckingType = .no
        controller.searchBar.returnKeyType = .done
        controller.showsSearchResultsController = true
        return controller
    }()

    private lazy var tableView = UITableView(frame: view.bounds, style: .insetGrouped)

    // MARK: - Lifecycle

    public init(
        model: MessageForwardingViewModel,
        searchResultsViewController: RecipientSearchResultsViewController,
        businessInjector: any BusinessInjectorProtocol
    ) throws {
        let inputModel = try MessageForwardingBottomViewModel(message: model.message)
        self.model = model
        self.messageInputModel = inputModel
        self.searchResultsViewController = searchResultsViewController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        tipObservation?.cancel()
        tipObservation = nil
    }

    // MARK: - Super overrides

    override public func viewDidLoad() {
        super.viewDidLoad()
        
        setupDelegates()
        setupViews()
        observeModelUpdates()
        observeTipStatus()
        updateTipEligibility()
    }

    override public func viewWillAppear(_ animated: Bool) {
        model.viewWillAppear()
        carouselView.invalidateLayout()
        super.viewWillAppear(animated)
    }
    
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Update bottom inset whenever the layout changes to allow scrolling above the `messageForwardingBottomView`
        
        // The safe area is automatically added to the insets, thus we remove it here
        let newBottomInset = view.frame.maxY - messageForwardingBottomView.frame.minY - tableView.safeAreaInsets.bottom
        
        tableView.contentInset = UIEdgeInsets(
            top: tableView.contentInset.top,
            left: tableView.contentInset.left,
            bottom: newBottomInset,
            right: tableView.contentInset.right
        )
        
        tableView.scrollIndicatorInsets = UIEdgeInsets(
            top: tableView.verticalScrollIndicatorInsets.top,
            left: tableView.horizontalScrollIndicatorInsets.left,
            bottom: newBottomInset,
            right: tableView.horizontalScrollIndicatorInsets.right
        )
    }

    override public func updateColors() {
        view.backgroundColor = Colors.backgroundGroupedViewController
    }

    // MARK: - Private Methods

    private var searchResultsViewModel: RecipientSearchResultsViewModel {
        searchResultsViewController.model
    }

    private lazy var messageForwardingBottomView: MessageForwardingBottomView = {
        let view = MessageForwardingBottomView(model: self.messageInputModel)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private func cellProvider(
        _ tableView: UITableView,
        _ indexPath: IndexPath,
        _ itemIdentifier: ItemID
    ) -> UITableViewCell? {
        guard let item = model.selectableItem(for: itemIdentifier) else {
            return nil
        }

        switch item.item {
        case let .contact(contact):
            let cell: ContactCell = tableView.dequeueCell(for: indexPath)
            cell.content = .contact(contact)
            cell.selectionStyle = .none
            cell.hasCheckmark = true
            cell.setSelected(item.isSelected, animated: false)

            return cell

        case let .group(group):
            let cell: GroupCell = tableView.dequeueCell(for: indexPath)
            cell.group = group
            cell.selectionStyle = .none
            cell.hasCheckmark = true
            cell.setSelected(item.isSelected, animated: false)

            return cell

        case let .distributionList(list):
            let cell: DistributionListCell = tableView.dequeueCell(for: indexPath)
            cell.distributionList = list
            cell.selectionStyle = .none
            cell.hasCheckmark = true
            cell.setSelected(item.isSelected, animated: false)

            return cell
        }
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            messageForwardingBottomView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            messageForwardingBottomView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            messageForwardingBottomView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        ])
    }

    private func setupViews() {
        view.addSubview(contentView)
        view.addSubview(messageForwardingBottomView)
        contentView.addArrangedSubview(carouselView)
        contentView.addArrangedSubview(tableView)
        
        setupConstraints()
        setupNavigationBar()
        updateCarouselView()
        setupTableView()
        setupSearch()
        addTapGesture()
        observeSystemNotifications()
    }

    private func setupNavigationBar() {
        navigationItem.title = model.screenTitle
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.leftBarButtonItem = UIBarButtonItem.cancelButton(
            target: self, selector: #selector(handleCancelButtonTapped)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem.sendButton(
            target: self, selector: #selector(handleSendButtonTapped)
        )
    }

    private func setupTableView() {
        tableView.registerCell(ContactCell.self)
        tableView.registerCell(GroupCell.self)
        tableView.registerCell(DistributionListCell.self)

        tableView.delegate = self
        tableView.allowsMultipleSelection = true
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 4))
        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 4))
        tableView.sectionHeaderTopPadding = 0.0
    }

    private func setupSearch() {
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false

        if #available(iOS 18.0, *) {
            navigationItem.preferredSearchBarPlacement = .stacked
        }
        definesPresentationContext = true
    }
    
    private func setupDelegates() {
        navigationController?.presentationController?.delegate = self
    }

    private func addTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGestureRecognized))
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self
        contentView.addGestureRecognizer(tapGesture)
    }

    private func observeSystemNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentSizeCategoryDidChange),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOrientationChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }

    private func observeModelUpdates() {
        withObservationTracking {
            _ = model.isConfirmationButtonEnabled
            _ = model.itemIdentifiers
            _ = model.selectedItemIdentifiers
            _ = model.shouldDismiss
        } onChange: {
            Task { @MainActor [weak self] in
                self?.updateSnapshot()
                self?.updateCarouselView()
                self?.updateConfirmationButton()
                self?.updateDismiss()
                self?.observeModelUpdates()
            }
        }
    }

    private func observeTipStatus() {
        tipObservation = tipObservation ?? Task { @MainActor in
            for await shouldDisplay in tip.shouldDisplayUpdates {
                if shouldDisplay {
                    showTip()
                }
                else {
                    dismissTip()
                }
            }
        }
    }

    private func updateTipEligibility() {
        if case .caption = messageInputModel.getAdditionalContent() {
            TipKitManager.ThreemaForwardingCaptionInfoTip.isInCorrectScenario = true
        }
        else {
            TipKitManager.ThreemaForwardingCaptionInfoTip.isInCorrectScenario = false
        }
    }

    private func updateSnapshot() {
        var snapshot = DataSourceSnapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(model.itemIdentifiers, toSection: .main)
        snapshot.reconfigureItems(model.changedItemIdentifiers)
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    private func updateCarouselView() {
        carouselView.configure()
        let carouselTopPadding = NSDirectionalEdgeInsets(top: 4, leading: 0, bottom: 0, trailing: 0)
        contentView.directionalLayoutMargins = carouselView.isHidden ? .zero : carouselTopPadding
    }

    private func updateConfirmationButton() {
        navigationItem.rightBarButtonItem?.isEnabled = model.isConfirmationButtonEnabled
    }

    private func updateDismiss() {
        if model.shouldDismiss {
            dismiss(animated: true)
        }
    }

    private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func showTip() {
        guard tipPopoverController == nil, let sourceItem = messageForwardingBottomView.tipAnchorView else {
            return
        }

        let frame = sourceItem.frame
        let sourceRect = CGRect(x: frame.midX, y: frame.minY, width: 1, height: 1)
        let controller = TipUIPopoverViewController(tip, sourceItem: sourceItem)
        if #unavailable(iOS 26.0) {
            controller.view.backgroundColor = .tertiarySystemGroupedBackground
        }
        
        if let popover = controller.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = sourceRect
            popover.permittedArrowDirections = .down
        }

        present(controller, animated: true)
        tipPopoverController = controller
    }

    private func dismissTip() {
        tipPopoverController?.dismiss(animated: true)
        tipPopoverController = nil
    }

    // MARK: - ObjC methods

    @objc private func handleCancelButtonTapped() {
        dismiss(animated: true)
    }

    @objc private func handleSendButtonTapped() {
        model.handleConfirmationButtonTapped(
            sendAsFile: messageInputModel.isSendingAsFile,
            additionalContent: messageInputModel.getAdditionalContent()
        )
    }

    @objc private func handleTapGestureRecognized(_ gesture: UITapGestureRecognizer) {
        dismissKeyboard()
    }

    @objc private func contentSizeCategoryDidChange() {
        carouselView.invalidateLayout()
    }

    @objc private func handleOrientationChange() {
        carouselView.invalidateLayout()
    }
}

// MARK: - UITableViewDelegate

extension MessageForwardingViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let identifier = dataSource.itemIdentifier(for: indexPath) {
            model.selectItem(with: identifier)
        }
        dismissKeyboard()
    }

    public func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if let identifier = dataSource.itemIdentifier(for: indexPath) {
            model.deselectItem(with: identifier)
        }
        dismissKeyboard()
    }

    public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let identifier = dataSource.itemIdentifier(for: indexPath) else {
            return
        }

        let shouldBeSelected = model.isIdentifierSelected(identifier)
        let isCurrentlySelected = tableView.indexPathsForSelectedRows?.contains(indexPath) ?? false

        // Only update if state doesn't match
        if shouldBeSelected, !isCurrentlySelected {
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        }
        else if !shouldBeSelected, isCurrentlySelected {
            tableView.deselectRow(at: indexPath, animated: false)
        }
        else {
            // No-op
        }
    }
}

// MARK: - UIScrollViewDelegate

extension MessageForwardingViewController: UIScrollViewDelegate {
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        dismissKeyboard()
    }
}

// MARK: - ItemSelectionHandler

extension MessageForwardingViewController: ItemSelectionHandler {
    public func didSelect(id: ItemID) {
        dismissKeyboard()
    }

    public func didDeselect(id: ItemID) {
        defer { dismissKeyboard() }
        guard let indexPath = dataSource.indexPath(for: id)
        else {
            return
        }

        model.deselectItem(with: id)

        // Update the cell's visual state if it's currently visible on screen.
        // If the cell has been scrolled off-screen (cell is nil), no action is needed—
        // when it's dequeued again, willDisplay will sync its state from the model.
        let cell = tableView.cellForRow(at: indexPath)
        cell?.setSelected(false, animated: true)
    }

    public func selectionFor(id: ItemID) -> Bool {
        false
    }

    public func selectedItems() -> [SelectableItem] {
        model.selectableItemsForSelectedIdentifiers()
    }
}

// MARK: - SelectedItemsHeaderViewDelegate

extension MessageForwardingViewController: SelectedItemsHeaderViewDelegate {
    public func header(_ header: SelectedItemsHeaderView, itemForIndexPath indexPath: IndexPath) -> SelectableItem? {
        model.selectableItemForSelectedIdentifier(at: indexPath.row)
    }
}

// MARK: - UISearchResultsUpdating

extension MessageForwardingViewController: UISearchResultsUpdating {
    public func updateSearchResults(for searchController: UISearchController) {
        searchResultsViewModel.updateSearchResults(for: searchController.searchBar.text)
    }
}

// MARK: - UISearchControllerDelegate

extension MessageForwardingViewController: UISearchControllerDelegate {
    public func willPresentSearchController(_ searchController: UISearchController) {
        searchResultsViewModel.updateSelectedItemIdentifiers(model.selectedItemIdentifiers)
    }

    public func willDismissSearchController(_ searchController: UISearchController) {
        let ids = searchResultsViewModel.selectedItemIdentifiers
        model.updateSelectedItemIdentifiers(ids)
        tableView.reloadData()
    }
}

// MARK: - UIGestureRecognizerDelegate

extension MessageForwardingViewController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let locationInBottomView = touch.location(in: messageForwardingBottomView)
        if messageForwardingBottomView.point(inside: locationInBottomView, with: nil) {
            return false
        }

        // Let tableView cells handle the touches
        let locationInTableView = touch.location(in: tableView)
        if tableView.indexPathForRow(at: locationInTableView) != nil {
            return false
        }

        // For carousel: allow gesture EXCEPT when touching buttons
        let locationInCarousel = touch.location(in: carouselView)
        if !carouselView.isHidden, carouselView.point(inside: locationInCarousel, with: nil) {
            if let touchedView = carouselView.hitTest(locationInCarousel, with: nil),
               touchedView is UIButton || touchedView.superview is UIButton {
                return false // Let the button handle the touch
            }
            // Touch is on carousel but not on a button, allow gesture to dismiss keyboard
            return true
        }

        // Allow gesture to recognize all other touches
        return true
    }
}

// MARK: - UIAdaptivePresentationControllerDelegate

extension MessageForwardingViewController: UIAdaptivePresentationControllerDelegate {
    public func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        // TODO: (IOS-6075) Only disable interactive dismissal if there was any user input
        false
    }
}
