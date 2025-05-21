//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

import Foundation
import ThreemaMacros

class SettingsCollectionViewDataSource: UICollectionViewDiffableDataSource<
    SettingsCollectionViewDataSource.Section,
    SettingsCollectionViewDataSource.Row
> {
    
    // MARK: - Properties

    private let businessInjector = BusinessInjector.ui
    private weak var collectionView: UICollectionView?
    private weak var coordinator: SettingsCoordinator?
    
    private let cellProvider: SettingsCollectionViewDataSource.CellProvider = { collectionView, indexPath, item in
        
        switch item {
            
        case .betaFeedback, .developer, .privacy, .appearance, .noftifications, .chat, .media, .storage, .passcode,
             .calls, .desktop, .web, .rate, .invite, .channel, .support, .policy, .tos, .license, .advanced:
            let cell: SettingsCollectionViewCell = collectionView.dequeueCell(for: indexPath)
            cell.rowType = item
            return cell
        
        case .workAd:
            guard let cell: UICollectionViewListCell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "Default",
                for: indexPath
            ) as? UICollectionViewListCell else {
                return nil
            }
            var content = cell.defaultContentConfiguration()
            content.text = #localize("settings_threema_work")
            content.secondaryText = #localize("settings_threema_work_subtitle")
            content.image = UIImage(resource: .threemaWorkSettings)
            cell.contentConfiguration = content
            cell.accessories = [.disclosureIndicator()]
            return cell
        
        case .network, .version, .workLicense:
            guard let cell: UICollectionViewListCell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "Default",
                for: indexPath
            ) as? UICollectionViewListCell else {
                return nil
            }
            var content = cell.defaultContentConfiguration()
            content.text = item.title
            cell.contentConfiguration = content

            if case .network = item {
                let sc = BusinessInjector.ui.serverConnector
                let statusText = "status_\(sc.name(for: sc.connectionState))"
                    .localized
                    .appending(sc.isIPv6Connection ? " (IPv6)" : "")
                    .appending(sc.isProxyConnection ? " (Proxy)" : "")
                cell.accessories = [.label(text: statusText)]
            }
            else if case .version = item {
                cell.accessories = [.label(text: ThreemaUtility.appAndBuildVersionPretty)]
            }
            else if case .workLicense = item {
                cell.accessories = [.label(text: BusinessInjector.ui.licenseStore.licenseUsername ?? "")]
            }

            return cell
        }
    }
    
    // MARK: - Lifecycle
    
    init(collectionView: UICollectionView, coordinator: SettingsCoordinator?) {
        self.collectionView = collectionView
        self.coordinator = coordinator
        
        super.init(collectionView: collectionView, cellProvider: cellProvider)
        
        registerCells()
        businessInjector.serverConnector.registerConnectionStateDelegate(delegate: self)
    }
    
    deinit {
        businessInjector.serverConnector.unregisterConnectionStateDelegate(delegate: self)
    }
    
    private func registerCells() {
        guard let collectionView else {
            assertionFailure("Collection view must not be nil.")
            return
        }
        
        collectionView.registerCell(SettingsCollectionViewCell.self)
        collectionView.register(UICollectionViewListCell.self, forCellWithReuseIdentifier: "Default")
    }
    
    func configureData() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Row>()
        // Dev
        if !Section.dev.rows.isEmpty {
            snapshot.appendSections([.dev])
            snapshot.appendItems(Section.dev.rows)
        }

        // General
        snapshot.appendSections([.general])
        snapshot.appendItems(Section.general.rows)
        
        // Desktop
        if !Section.desktop.rows.isEmpty {
            snapshot.appendSections([.desktop])
            snapshot.appendItems(Section.desktop.rows)
        }
        
        // Status
        snapshot.appendSections([.status])
        snapshot.appendItems(Section.status.rows)

        // Work Add
        if !Section.workAdvertising.rows.isEmpty {
            snapshot.appendSections([.workAdvertising])
            snapshot.appendItems(Section.workAdvertising.rows)
        }
        
        // Social
        if !Section.social.rows.isEmpty {
            snapshot.appendSections([.social])
            snapshot.appendItems(Section.social.rows)
        }
        
        // Support
        snapshot.appendSections([.support])
        snapshot.appendItems(Section.support.rows)

        apply(snapshot)
    }
    
    func indexPathForItem(_ item: Row) -> IndexPath? {
        indexPath(for: item)
    }
    
    func canSelectItem(at indexPath: IndexPath) -> Bool {
        guard let identifier = itemIdentifier(for: indexPath) else {
            return false
        }
        
        if case .network = identifier {
            return false
        }
        else if case .workLicense = identifier {
            return false
        }
        else {
            return true
        }
    }
    
    func didSelectItem(at indexPath: IndexPath) {
        guard let coordinator, let identifier = itemIdentifier(for: indexPath) else {
            return
        }
        
        switch identifier {
        case .betaFeedback:
            coordinator.show(.betaFeedback)
            
        case .developer:
            coordinator.show(.developer)
            
        case .privacy:
            coordinator.show(.privacy)
            
        case .appearance:
            coordinator.show(.appearance)
            
        case .noftifications:
            coordinator.show(.noftifications)
            
        case .chat:
            coordinator.show(.chat)
            
        case .media:
            coordinator.show(.media)
            
        case .storage:
            coordinator.show(.storage)
            
        case .passcode:
            coordinator.show(.passcode)
            
        case .calls:
            coordinator.show(.calls)
            
        case .desktop:
            coordinator.show(.desktop)
            
        case .web:
            coordinator.show(.web)
            
        case .network:
            break
            
        case .version:
            versionSelected()
            
        case .workLicense:
            break
            
        case .rate:
            rateSelected()
            
        case .invite:
            guard let sourceView = collectionView?.cellForItem(at: indexPath) as? UICollectionViewCell else {
                return
            }
            coordinator.show(.invite(sourceView: sourceView))
            
        case .channel:
            coordinator.show(.channel)
            
        case .workAd:
            workAdSelected()
            
        case .support:
            coordinator.show(.support)
            
        case .policy:
            coordinator.show(.policy)
            
        case .tos:
            coordinator.show(.tos)
            
        case .license:
            coordinator.show(.license)
            
        case .advanced:
            coordinator.show(.advanced)
        }
    }
    
    private func versionSelected() {
        UIPasteboard.general.string = ThreemaUtility.appAndBuildVersionPretty
        NotificationPresenterWrapper.shared.present(type: .copySuccess)
    }
    
    private func rateSelected() {
        if let link = TargetManager.rateLink {
            UIApplication.shared.open(link, options: [:], completionHandler: nil)
        }
    }
    
    private func workAdSelected() {
        if let appURL = URL(string: "threemawork://app"), UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL, options: [:], completionHandler: nil)
        }
        else {
            coordinator?.show(.workInfo)
        }
    }
}

// MARK: - ConnectionStateDelegate

extension SettingsCollectionViewDataSource: ConnectionStateDelegate {
    func changed(connectionState state: ConnectionState) {
        var snapshot = snapshot()
        snapshot.reconfigureItems([.network])
        apply(snapshot)
    }
}
