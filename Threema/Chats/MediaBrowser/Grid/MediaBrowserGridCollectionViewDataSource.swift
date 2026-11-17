import Foundation
import ThreemaMacros

/// Media grouped by month, each section is identified by the first day of its month
final class MediaBrowserGridCollectionViewDataSource: UICollectionViewDiffableDataSource<Date, NSManagedObjectID>,
    MediaBrowserMediaManagerDelegate {

    // MARK: - Private properties

    /// Called after the media changed, e.g. to update the footer
    var onDidApplySnapshot: (() -> Void)?

    private let mediaManager: MediaBrowserMediaManager

    // MARK: - Lifecycle
    
    init(
        mediaManager: MediaBrowserMediaManager,
        collectionView: MediaBrowserGridCollectionView,
        cellProvider: @escaping CellProvider
    ) {
        self.mediaManager = mediaManager
        
        super.init(collectionView: collectionView, cellProvider: cellProvider)

        let headerRegistration = UICollectionView.SupplementaryRegistration<MediaBrowserGridSectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] header, _, indexPath in
            header.title = self?.sectionIdentifier(for: indexPath.section).map(DateFormatter.relativeMonth(for:))
        }
        let footerRegistration = UICollectionView.SupplementaryRegistration<MediaBrowserGridFooterView>(
            elementKind: UICollectionView.elementKindSectionFooter
        ) { [weak self] footer, _, _ in
            footer.text = self?.footerText
        }
        supplementaryViewProvider = { collectionView, kind, indexPath in
            kind == UICollectionView.elementKindSectionFooter
                ? collectionView.dequeueConfiguredReusableSupplementary(using: footerRegistration, for: indexPath)
                : collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
        }
    
        configureData()
    }
    
    // MARK: - Configuration
    
    private func configureData() {
        applySnapshot(for: mediaManager.allObjectIDs, reloadIDs: [], reconfigureIDs: [], animated: false)
    }
    
    // MARK: - Helpers

    func objectID(for indexPath: IndexPath) -> NSManagedObjectID? {
        itemIdentifier(for: indexPath)
    }

    /// Number of media
    var footerText: String {
        String.localizedStringWithFormat(
            #localize("media_browser_footer_label_media"),
            mediaManager.allObjectIDs.count
        )
    }

    // MARK: - MediaBrowserMediaManagerDelegate

    func mediaChanged(
        _ source: MediaBrowserMediaManager,
        didUpdateObjectIDs objectIDs: [NSManagedObjectID],
        reloadIDs: [NSManagedObjectID],
        reconfigureIDs: [NSManagedObjectID]
    ) {
        applySnapshot(for: objectIDs, reloadIDs: reloadIDs, reconfigureIDs: reconfigureIDs, animated: true)
    }

    // MARK: - Private

    private func applySnapshot(
        for objectIDs: [NSManagedObjectID],
        reloadIDs: [NSManagedObjectID],
        reconfigureIDs: [NSManagedObjectID],
        animated: Bool
    ) {
        var snapshot = NSDiffableDataSourceSnapshot<Date, NSManagedObjectID>()

        // The media is sorted by date, so all items of a month follow each other
        var month: Date?
        var monthObjectIDs = [NSManagedObjectID]()
        for objectID in objectIDs {
            let itemMonth = mediaManager.date(for: objectID)
                .flatMap { Calendar.current.dateInterval(of: .month, for: $0)?.start }
                ?? month
                ?? .distantPast

            if itemMonth != month, let month {
                snapshot.appendSections([month])
                snapshot.appendItems(monthObjectIDs, toSection: month)
                monthObjectIDs.removeAll()
            }
            month = itemMonth
            monthObjectIDs.append(objectID)
        }
        if let month {
            snapshot.appendSections([month])
            snapshot.appendItems(monthObjectIDs, toSection: month)
        }

        snapshot.reconfigureItems(reconfigureIDs + reloadIDs)
       
        apply(snapshot, animatingDifferences: animated) { [weak self] in
            self?.onDidApplySnapshot?()
        }
    }
}
