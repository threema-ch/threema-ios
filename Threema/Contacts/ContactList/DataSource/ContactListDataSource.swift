//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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

class ContactListDataSource<
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
    private var contentProvider: (CellProvider, Provider) -> ContactListDataSource
        .CellProvider = { cellProvider, provider in
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
        let stackView = UIStackView(arrangedSubviews: [headerLabel, spacerView, headerButton])
        stackView.axis = .horizontal
        stackView.distribution = .fillProportionally
        stackView.spacing = 8
        stackView.layer.cornerRadius = 8
        stackView.backgroundColor = .secondarySystemFill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.layoutMargins = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        return stackView
    }()
    
    private lazy var headerLabel: UILabel = {
        let label = UILabel()
        label.text = String.localizedStringWithFormat(
            #localize("contact_list_limited_access_header_label"),
            TargetManager.appName
        )
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textAlignment = .left
        return label
    }()
    
    private lazy var spacerView: UIView = {
        let spacerView = UIView()
        
        let spacerViewWidthConstraint = spacerView.widthAnchor.constraint(equalToConstant: .greatestFiniteMagnitude)
        spacerViewWidthConstraint.priority = .defaultLow
        spacerViewWidthConstraint.isActive = true
        
        return spacerView
    }()
    
    private lazy var headerButton: UIButton = {
        
        var config = UIButton.Configuration.filled()
        config.buttonSize = .mini
        config.title = #localize("contact_list_limited_access_header_button")
        config.baseForegroundColor = .white
        let button = UIButton(type: .system)
        button.configuration = config
        button.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.setContentHuggingPriority(.required, for: .horizontal)

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
        self.tableView = tableView
        self.sourceType = sourceType
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
    
    override func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
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
    
    public func checkLimitedAccessHeader() {
        guard let tableView, #available(iOS 18, *), UserSettings.shared().syncContacts, sourceType == .contacts,
              CNContactStore.authorizationStatus(for: .contacts) == .limited, snapshot().numberOfItems > 0 else {
            tableView?.tableHeaderView = nil
            return
        }
        tableView.tableHeaderView = headerView
        
        NSLayoutConstraint.activate([
            headerView.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            headerView.widthAnchor
                .constraint(
                    lessThanOrEqualToConstant: tableView.bounds.width - tableView.directionalLayoutMargins
                        .trailing - tableView.directionalLayoutMargins.leading
                ),
        ])
        
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
        if let url = URL(string: UIApplication.openSettingsURLString) {
            Task { await UIApplication.shared.open(url) }
        }
    }
}
