/// Simple subclass to provide easy header and footer `UICollectionReusableView` configuration
final class CollectionViewDiffableSimpleHeaderAndFooterDataSource<
    Section: Hashable,
    Row: Hashable
>: UICollectionViewDiffableDataSource<Section, Row> {
    typealias SupplementaryProvider = (UICollectionView, Section, IndexPath) -> UICollectionReusableView
    
    let headerProvider: SupplementaryProvider?
    let footerProvider: SupplementaryProvider?
    
    /// Create a new diffable data source
    /// - Parameters:
    ///   - collectionView: Collection view the data source will be attached to
    ///   - cellProvider: Cell provider for cells
    ///   - headerProvider: Called to ask for an optional header string
    ///   - footerProvider: Called to ask for an optional footer string
    init(
        collectionView: UICollectionView,
        cellProvider: @escaping UICollectionViewDiffableDataSource<Section, Row>.CellProvider,
        headerProvider: SupplementaryProvider? = nil,
        footerProvider: SupplementaryProvider? = nil
    ) {
        self.headerProvider = headerProvider
        self.footerProvider = footerProvider
        
        super.init(collectionView: collectionView, cellProvider: cellProvider)
    }
    
    @available(*, unavailable)
    override init(
        collectionView: UICollectionView,
        cellProvider: @escaping UICollectionViewDiffableDataSource<Section, Row>.CellProvider
    ) {
        fatalError("Not supported.")
    }
    
    override func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            guard let headerProvider else {
                fatalError("No header provider set")
            }
            let section = snapshot().sectionIdentifiers[indexPath.section]
            return headerProvider(collectionView, section, indexPath)
        }
        else {
            guard let footerProvider else {
                fatalError("No footer provider set.")
            }
            let section = snapshot().sectionIdentifiers[indexPath.section]
            return footerProvider(collectionView, section, indexPath)
        }
    }
}
