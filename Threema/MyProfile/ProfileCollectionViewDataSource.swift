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

        // Backups
        snapshot.appendSections([.backups])
        snapshot.appendItems(Section.backups.rows)
        
        // ID
        snapshot.appendSections([.id])
        snapshot.appendItems(Section.id.rows)
        
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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reconfigureHeader),
            name: .profileUIRefresh,
            object: nil
        )
    }
    
    private func reconfigureRevocationPassword() {
        var snapshot = snapshot()
        
        guard snapshot.itemIdentifiers.contains(.revocationPassword) else {
            return
        }
        
        snapshot.reconfigureItems([.revocationPassword])
        apply(snapshot)
    }
    
    @objc private func reconfigureLinkedPhone() {
        var snapshot = snapshot()
        
        guard snapshot.itemIdentifiers.contains(.phone) else {
            return
        }
        
        snapshot.reconfigureItems([.phone])
        apply(snapshot)
    }
    
    @objc private func reconfigureLinkedEmail() {
        var snapshot = snapshot()
        
        guard snapshot.itemIdentifiers.contains(.mail) else {
            return
        }
        
        snapshot.reconfigureItems([.mail])
        apply(snapshot)
    }

    @objc private func reconfigureHeader() {
        var snapshot = snapshot()
        
        guard snapshot.itemIdentifiers.contains(.header) else {
            return
        }
        
        snapshot.reconfigureItems([.header])
        apply(snapshot)
    }
}
