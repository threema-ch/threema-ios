import CocoaLumberjackSwift
import Combine
import Foundation
import ThreemaFramework
import ThreemaMacros
import UIKit

// MARK: - ContactListDataSourceProviderProtocol

protocol ContactListDataSourceProviderProtocol<ID, BusinessEntity> {
    associatedtype ID: ContactObjectID
    associatedtype BusinessEntity
    typealias ContactListSnapshot = NSDiffableDataSourceSnapshot<String, ID>

    func entity(for id: ID) -> BusinessEntity?
    var currentSnapshot: AnyPublisher<ContactListSnapshot, Never> { get }
}

extension ContactListDataSource {
    typealias Section = Hashable
    typealias Row = Hashable

    enum SourceType {
        case contacts, groups, distributionLists
    }
}

// MARK: - ContactListDataSource

final class ContactListDataSource<
    CellType: ContactListCellProviderProtocol.ContactListCellType,
    BusinessEntity: NSObject,
    Provider: ContactListDataSourceProviderProtocol<NSManagedObjectID, BusinessEntity>,
    CellProvider: ContactListCellProviderProtocol<CellType, BusinessEntity>
>: UITableViewDiffableDataSource<String, Provider.ID> {
    
    public var contentUnavailableConfiguration: ThreemaTableContentUnavailableView.Configuration {
        didSet {
            contentUnavailable = tableView?
                .setupContentUnavailableView(configuration: contentUnavailableConfiguration)
            snapshot().itemIdentifiers.isEmpty ? contentUnavailable?.show() : contentUnavailable?.hide()
        }
    }
    
    private var sourceType: SourceType
    
    private weak var tableView: UITableView?
    private var snapshotSubscription: Cancellable?
    private var sectionTitles: [String] { ThreemaLocalizedIndexedCollation.sectionIndexTitles }
    private var contentProvider: (CellProvider, Provider)
        -> ContactListDataSource.CellProvider = { cellProvider, provider in
            { tableView, indexPath, itemIdentifier in
                cellProvider.dequeueCell(
                    for: indexPath,
                    and: provider.entity(for: itemIdentifier),
                    in: tableView
                )
            }
        }
    
    private var tableIndexTitles: [String] {
        (snapshot().sectionIdentifiers + [.broadcasts]).compactMap { str in
            guard let i = Int(str), i >= 0, i < sectionTitles.count else {
                return str
            }
            return sectionTitles[i]
        }
    }
    
    private let sectionIndexEnabled: Bool
    private var contentUnavailable: (show: () -> Void, hide: () -> Void)?
    
    private lazy var footerView = UIView()
    private lazy var countLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.textColor = .secondaryLabel
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var headerView: UIStackView = {
        let stackView = AccessibleStackView(arrangedSubviews: [headerLabel, headerButton])
        stackView.onActivate = { [weak self] in
            self?.openSettings()
        }
        stackView.axis = headerAxis()
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.directionalLayoutMargins = .zero
        
        stackView.isAccessibilityElement = true
        stackView.accessibilityLabel = #localize("contact_list_limited_access_header_label")
        stackView.accessibilityTraits = .button
        stackView.accessibilityHint = #localize("contact_list_limited_access_header_accessibility_hint")
        
        return stackView
    }()
    
    private lazy var headerLabel: UILabel = {
        let label = UILabel()
        label.text = #localize("contact_list_limited_access_header_label")
        label.font = UIFont.preferredFont(forTextStyle: .callout)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textAlignment = .left
        label.isAccessibilityElement = false
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return label
    }()
    
    private lazy var headerButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.buttonSize = .mini
        config.title = #localize("contact_list_limited_access_header_button")
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .callout
            return outgoing
        }
        config.baseForegroundColor = .white
        let button = UIButton(type: .system)
        button.configuration = config
        button.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.isAccessibilityElement = false

        return button
    }()
    
    // MARK: - Lifecycle
    
    init(
        sourceType: SourceType,
        provider: Provider,
        cellProvider: CellProvider,
        in tableView: UITableView,
        sectionIndexEnabled: Bool = true,
        contentUnavailableConfiguration: ThreemaTableContentUnavailableView.Configuration
    ) {
        self.sourceType = sourceType
        self.tableView = tableView
        self.sectionIndexEnabled = sectionIndexEnabled
        self.contentUnavailableConfiguration = contentUnavailableConfiguration
        
        super.init(
            tableView: tableView,
            cellProvider: contentProvider(cellProvider, provider)
        )
        
        cellProvider.registerCells(in: tableView)
        subscribe(to: provider)
        
        setupFooter(for: tableView)
    }
    
    deinit {
        snapshotSubscription?.cancel()
    }
    
    // MARK: - Overrides
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sectionIndexEnabled ? tableIndexTitles[section] : nil
    }

    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        sectionIndexEnabled ? sectionTitles : nil
    }
    
    override func tableView(
        _ tableView: UITableView,
        sectionForSectionIndexTitle title: String,
        at index: Int
    ) -> Int {
        tableIndexTitles.firstIndex(of: title) ?? 0
    }
    
    private func subscribe(to provider: Provider) {
        snapshotSubscription = provider.currentSnapshot.sink { [weak self] snapshot in
            guard let self else {
                return
            }
            apply(snapshot)
            didUpdate(snapshot: snapshot)
        }
    }

    // MARK: - Private functions
    
    private func didUpdate(snapshot: Provider.ContactListSnapshot) {
        guard snapshot.numberOfItems > 0 else {
            contentUnavailable?.show()
            footerView.isHidden = true
            return
        }
        
        contentUnavailable?.hide()
        footerView.isHidden = false

        switch sourceType {
        case .contacts:
            countLabel.text = String.localizedStringWithFormat(
                #localize("contact_list_footer_label_contacts"),
                snapshot.numberOfItems
            )
        case .groups:
            countLabel.text = String.localizedStringWithFormat(
                #localize("contact_list_footer_label_groups"),
                snapshot.numberOfItems
            )
        case .distributionLists:
            countLabel.text = String.localizedStringWithFormat(
                #localize("contact_list_footer_label_distribution_lists"),
                snapshot.numberOfItems
            )
        }
    }
    
    public func updateLimitedAccessHeaderIfNeeded() {
        guard tableView?.tableHeaderView != nil else {
            return
        }
        
        headerView.axis = headerAxis()
    }
    
    public func checkLimitedAccessHeader() {
        guard
            let tableView,
            #available(iOS 18, *),
            UserSettings.shared().syncContacts,
            sourceType == .contacts,
            CNContactStore.authorizationStatus(for: .contacts) == .limited,
            snapshot().numberOfItems > 0
        else {
            tableView?.tableHeaderView = nil
            return
        }
        
        tableView.tableHeaderView = headerView
        
        NSLayoutConstraint.activate(
            [
                headerView.leadingAnchor.constraint(
                    equalTo: tableView.safeAreaLayoutGuide.leadingAnchor,
                    constant: tableView.directionalLayoutMargins.leading
                ),
                headerView.trailingAnchor.constraint(
                    equalTo: tableView.safeAreaLayoutGuide.trailingAnchor,
                    constant: -tableView.directionalLayoutMargins.trailing
                ),
                headerView.topAnchor.constraint(equalTo: tableView.topAnchor),
            ]
        )
        
        tableView.layoutSubviews()
    }
    
    private func setupFooter(for tableView: UITableView) {
        footerView.addSubview(countLabel)
        
        let size = countLabel.systemLayoutSizeFitting(CGSize(
            width: tableView.bounds.width,
            height: UIView.layoutFittingCompressedSize.height
        ))
 
        footerView.frame = CGRect(origin: .zero, size: CGSize(width: tableView.bounds.width, height: size.height + 20))
       
        NSLayoutConstraint.activate([
            countLabel.centerXAnchor.constraint(equalTo: footerView.centerXAnchor),
            countLabel.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),
        ])
        
        tableView.tableFooterView = footerView
    }
    
    @objc private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        
        Task {
            await UIApplication.shared.open(url)
        }
    }
    
    private func headerAxis() -> NSLayoutConstraint.Axis {
        let isAccessibilityCategory =
            tableView?.traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        
        return isAccessibilityCategory == true ? .vertical : .horizontal
    }
}

// MARK: - Helper Types

private final class AccessibleStackView: UIStackView {
    var onActivate: (() -> Void)?
    
    override func accessibilityActivate() -> Bool {
        onActivate?()
        return onActivate != nil
    }
}
