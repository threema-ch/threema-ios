import SwiftUI
import ThreemaFramework
import ThreemaMacros
import TipKit
import UIKit

final class SelectContactListViewController: ThemedViewController {
    
    // MARK: - Private properties

    private var selectedContacts: [Contact] = []
    private var editData: EditData?
    private let contactSelectionMode: SelectContactListDisplayMode
    private let onSaveDisplayMode: OnSaveDisplayMode
    private let onEdit: (([Contact]) -> Void)?
    private let tip = TipKitManager.ThreemaNoteGroupCreationTip()
    private var tipObservation: Task<Void, Never>?
    private var tipPopoverController: TipUIPopoverViewController?

    private lazy var provider = ContactListProvider()
    private lazy var cellProvider = ContactListSelectionCellProvider()
    private lazy var carouselView = {
        let headerView = SelectedItemsHeaderView(
            collectionKind: contactSelectionMode.countLabelKind
        )
        headerView.setContentHuggingPriority(.required, for: .vertical)
        headerView.setContentCompressionResistancePriority(.required, for: .vertical)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.delegate = self
        return headerView
    }()

    private lazy var contentView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.distribution = .fill
        return stackView
    }()

    private lazy var tableViewController = SelectContactListTableViewController(
        coordinator: nil,
        cellProvider: cellProvider,
        provider: provider,
        businessInjector: BusinessInjector.ui,
        style: .insetGrouped
    )
    private lazy var searchController: UISearchController = {
        var controller = UISearchController(searchResultsController: contactListSearchResultsController)
        controller.delegate = self
        controller.searchResultsUpdater = contactListSearchResultsController
        controller.obscuresBackgroundDuringPresentation = false
        controller.searchBar.placeholder = #localize("contact_list_search_bar_placeholder")
        controller.searchBar.setValue(#localize("Done"), forKey: "cancelButtonText")
        return controller
    }()

    private lazy var contactListSearchResultsController = {
        let controller = ContactListSearchResultViewController(
            businessInjector: BusinessInjector.ui,
            cellProvider: cellProvider,
            provider: provider,
            allowsMultiSelect: true
        )
        controller.delegate = self
        
        return controller
    }()

    // MARK: - Lifecycle

    init(
        contentSelectionMode: SelectContactListDisplayMode,
        onSaveDisplayMode: OnSaveDisplayMode = .showDetails,
        onEdit: (([Contact]) -> Void)? = nil
    ) {
        self.onEdit = onEdit
        self.contactSelectionMode = contentSelectionMode
        self.onSaveDisplayMode = onSaveDisplayMode
        super.init(nibName: nil, bundle: nil)
    }
    
    @objc convenience init(
        forGroupCreation selectedContacts: [Contact],
        onSaveDisplayMode: OnSaveDisplayMode = .showDetails
    ) {
        self.init(
            contentSelectionMode: .group(.create(data: .init(contacts: selectedContacts))),
            onSaveDisplayMode: onSaveDisplayMode
        )
    }

    @objc convenience init(
        forListCreation selectedContacts: [Contact],
        onSaveDisplayMode: OnSaveDisplayMode = .showDetails
    ) {
        self.init(
            contentSelectionMode: .distributionList(.create(data: .init(contacts: selectedContacts))),
            onSaveDisplayMode: onSaveDisplayMode
        )
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        tipObservation?.cancel()
        tipObservation = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = contactSelectionMode.title
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        
        navigationItem.searchController = searchController
        
        preFillData()
        updateTipEligibility()
        updateNextButton()
        setupViews()
        addObservers()
        tableViewController.updateSelection()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        carouselView.configure()
        carouselView.invalidateLayout()
        super.viewWillAppear(animated)
    }

    // MARK: - Configuration
    
    private func updateNextButton() {
        
        if #available(iOS 26.0, *) {
            let item =
                if contactSelectionMode.isEdit {
                    UIBarButtonItem(
                        barButtonSystemItem: .add,
                        target: self,
                        action: #selector(nextTapped)
                    )
                }
                else {
                    UIBarButtonItem(
                        image: UIImage(systemName: "arrow.forward"),
                        style: .plain,
                        target: self,
                        action: #selector(nextTapped)
                    )
                }
            navigationItem.rightBarButtonItem = item
        }
        else {
            let title =
                if contactSelectionMode.isEdit {
                    #localize("Done")
                }
                else {
                    selectedContacts.isEmpty ? #localize("skip") : #localize("next")
                }
            
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: title,
                style: .done,
                target: self,
                action: #selector(nextTapped)
            )
        }
        if selectedContacts.count > Group.maxGroupMembers {
            navigationItem.rightBarButtonItem?.isEnabled = false
        }
    }

    private func preFillData() {
        selectedContacts = contactSelectionMode.selectedContacts
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func nextTapped() {
        guard !contactSelectionMode.isEdit else {
            onEdit?(selectedContacts)
            dismiss(animated: true)
            return
        }
        let data = EditData(
            name: editData?.name,
            profilePicture: editData?.profilePicture,
            contacts: selectedContacts
        )
        let config: CreateEditGroupDistributionListDisplayMode

        switch contactSelectionMode {
        case .group(.create):
            config = .group(.create(data: data))

        case .distributionList(.create):
            config = .distributionList(.create(data: data))

        case let .group(.clone(group)):
            config = .group(.clone(group: group, data: data))

        default:
            fatalError("Unsupported contact selection mode for this flow")
        }

        let controller = CreateEditGroupDistributionViewController(
            for: config,
            onSaveDisplayMode: onSaveDisplayMode
        ) { [weak self] editData in
            self?.editData = editData
            self?.selectedContacts = editData.contacts
            self?.updateNextButton()
            self?.carouselView.configure()
            self?.tableViewController.updateSelection()
        }

        navigationController?.pushViewController(controller, animated: true)
    }

    private func addObservers() {
        // Dynamic type
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentSizeCategoryDidChange),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )

        // Rotation
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOrientationChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )

        // Tip
        observeTipStatus()
    }

    private func setupViews() {
        tableViewController.delegate = self
        
        addChild(tableViewController)
        view.addSubview(contentView)
        view.backgroundColor = .systemGroupedBackground
        
        contentView.addArrangedSubview(carouselView)
        contentView.addArrangedSubview(tableViewController.view)
        contentView.setCustomSpacing(8, after: carouselView)
        
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        tableViewController.didMove(toParent: self)
        
        carouselView.configure()
    }
    
    override func updateColors() {
        super.updateColors()
        
        view.backgroundColor = Colors.backgroundGroupedViewController
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
        TipKitManager.ThreemaNoteGroupCreationTip.isInCorrectScenario = selectedContacts.isEmpty
    }

    private func showTip() {
        guard tipPopoverController == nil, let sourceItem = navigationItem.rightBarButtonItem else {
            return
        }

        let controller = TipUIPopoverViewController(tip, sourceItem: sourceItem)
        if #unavailable(iOS 26.0) {
            controller.view.backgroundColor = .tertiarySystemGroupedBackground
        }

        if let popover = controller.popoverPresentationController {
            popover.sourceItem = sourceItem
            popover.permittedArrowDirections = .up
        }

        present(controller, animated: true)
        tipPopoverController = controller
    }

    private func dismissTip() {
        tipPopoverController?.dismiss(animated: true)
        tipPopoverController = nil
    }

    // MARK: - Notification

    @objc func contentSizeCategoryDidChange() {
        carouselView.invalidateLayout()
        tableViewController.updateSelection()
    }

    @objc func handleOrientationChange() {
        carouselView.invalidateLayout()
    }
}

// MARK: - ItemSelectionHandler

extension SelectContactListViewController: ItemSelectionHandler {
    func selectedItems() -> [SelectableItem] {
        selectedContacts.map {
            SelectableItem(id: $0.objectID, item: .contact($0), isSelected: false)
        }
    }
    
    func didSelect(id: ItemID) {
        if selectedContacts.contains(where: { $0.objectID == id }) {
            return
        }
        guard let contact = provider.entity(for: id) else {
            return
        }
        carouselView.isHidden = false
        selectedContacts.append(contact)
        updateNextButton()
        carouselView.configure()
    }
    
    func didDeselect(id: ItemID) {
        selectedContacts.removeAll { $0.objectID == id }
        updateNextButton()
        carouselView.configure()
        tableViewController.updateSelection()
        
        carouselView.isHidden = selectedContacts.isEmpty
    }
    
    func selectionFor(id: ItemID) -> Bool {
        selectedContacts.contains { $0.objectID == id }
    }
}

// MARK: - UISearchControllerDelegate

extension SelectContactListViewController: UISearchControllerDelegate {
    func didDismissSearchController(_ searchController: UISearchController) {
        tableViewController.updateSelection()
        carouselView.configure()
    }
}

// MARK: - SelectedItemsHeaderViewDelegate

extension SelectContactListViewController: SelectedItemsHeaderViewDelegate {
    func header(
        _ header: ThreemaFramework.SelectedItemsHeaderView,
        itemForIndexPath indexPath: IndexPath
    ) -> ThreemaFramework.SelectableItem? {
        guard indexPath.row < selectedContacts.count else {
            return nil
        }
        let contact = selectedContacts[indexPath.row]
        return SelectableItem(id: contact.objectID, item: .contact(contact), isSelected: false)
    }
}
