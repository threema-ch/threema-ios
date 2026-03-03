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

final class ProfileCollectionViewDataSource: UICollectionViewDiffableDataSource<
    ProfileCollectionViewDataSource.Section,
    ProfileCollectionViewDataSource.Row
> {
    // MARK: - Properties

    private let businessInjector = BusinessInjector.ui
    private weak var collectionView: UICollectionView?
    private let onSelection: (Row) -> Void

    // MARK: - Lifecycle
    
    init(
        collectionView: UICollectionView,
        cellProvider: @escaping CellProvider,
        onSelection: @escaping (Row) -> Void
    ) {
        self.collectionView = collectionView
        self.onSelection = onSelection
        
        super.init(collectionView: collectionView, cellProvider: cellProvider)
        
        registerCells()
        configureFooters()
        addObservers()
    }

    private func registerCells() {
        guard let collectionView else {
            assertionFailure("Collection view must not be nil.")
            return
        }
        
        collectionView.registerCell(ProfileCollectionViewHeaderCell.self)
        collectionView.register(UICollectionViewListCell.self, forCellWithReuseIdentifier: "Default")
    }
    
    private func configureFooters() {
        let registration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionFooter
        ) { [weak self] supplementaryView, _, indexPath in
            
            guard let section = self?.sectionIdentifier(for: indexPath.section) else {
                return
            }
            var content = UIListContentConfiguration.groupedFooter()
            content.text = section.footerText
            
            supplementaryView.contentConfiguration = content
        }
        
        supplementaryViewProvider = { collectionView, elementKind, indexPath -> UICollectionReusableView? in
            if elementKind == UICollectionView.elementKindSectionFooter {
                return collectionView.dequeueConfiguredReusableSupplementary(using: registration, for: indexPath)
            }
            else {
                return nil
            }
        }
    }
    
    func configureData() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Row>()

        // Header
        snapshot.appendSections([.header])
        snapshot.appendItems(Section.header.rows)

        // Safe
        snapshot.appendSections([.safe])
        snapshot.appendItems(Section.safe.rows)
        
        // ID-Export
        snapshot.appendSections([.idExport])
        snapshot.appendItems(Section.idExport.rows)
        
        // Linking
        snapshot.appendSections([.linking])
        snapshot.appendItems(Section.linking.rows)
        
        // Public key
        snapshot.appendSections([.publicKey])
        snapshot.appendItems(Section.publicKey.rows)
        
        // Revoke / delete
        snapshot.appendSections([.revokeDelete])
        snapshot.appendItems(Section.revokeDelete.rows)
        
        apply(snapshot)
    }
    
    @objc func checkRevocationPassword() {
        RevocationKeyManager.shared.checkPasswordSetDate { [weak self] in
            self?.reconfigureRevocationPassword()
        }
    }
    
    func checkEmailVerification() {
        guard let identityStore = businessInjector.myIdentityStore as? MyIdentityStore,
              identityStore.linkEmailPending else {
            return
        }
        
        let connector = ServerAPIConnector()
        connector.checkLinkEmailStatus(identityStore, email: identityStore.linkedEmail) { [weak self] linked in
            // If we are linked, we update our state
            guard let self, linked else {
                return
            }
            reconfigureLinkedEmail()
        } onError: { _ in
            // No-op
        }
    }
    
    func indexPathForItem(_ item: Row) -> IndexPath? {
        indexPath(for: item)
    }
    
    func didSelectItem(at indexPath: IndexPath) {
        guard let identifier = itemIdentifier(for: indexPath) else {
            return
        }
        
        onSelection(identifier)
    }
    
    private func addObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reconfigureSafe),
            name: Notification.Name(kSafeBackupUIRefresh),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(checkRevocationPassword),
            name: Notification.Name(kRevocationPasswordUIRefresh),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reconfigureLinkedPhone),
            name: Notification.Name(kLinkedPhoneUIRefresh),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reconfigureLinkedEmail),
            name: Notification.Name(kLinkedEmailUIRefresh),
            object: nil
        )
    }
    
    @objc private func reconfigureSafe() {
        var snapshot = snapshot()
        snapshot.reconfigureItems([.threemaSafe])
        apply(snapshot)
    }
    
    private func reconfigureRevocationPassword() {
        var snapshot = snapshot()
        snapshot.reconfigureItems([.revocationPassword])
        apply(snapshot)
    }
    
    @objc private func reconfigureLinkedPhone() {
        var snapshot = snapshot()
        snapshot.reconfigureItems([.phone])
        apply(snapshot)
    }
    
    @objc private func reconfigureLinkedEmail() {
        var snapshot = snapshot()
        snapshot.reconfigureItems([.mail])
        apply(snapshot)
    }
}
