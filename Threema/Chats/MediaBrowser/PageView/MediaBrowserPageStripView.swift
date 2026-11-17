import Foundation
import ThreemaFramework

/// Thumbnails of all media in the pager, scrubbing or tapping one calls `onSelect`
final class MediaBrowserPageStripView: UIView, UICollectionViewDelegate {

    private enum Configuration {
        static let itemSize = CGSize(width: 26, height: 38)
        static let itemSpacing: CGFloat = 2
        /// Additional spacing on both sides of the selected item
        static let selectedItemSpacing: CGFloat = 6
        static let selectionAnimationDuration: TimeInterval = 0.2
    }

    private enum Section {
        case main
    }

    // MARK: - Public properties

    var onSelect: ((NSManagedObjectID) -> Void)?

    // MARK: - Private properties

    private let mediaManager: MediaBrowserMediaManager
    private var selectedObjectID: NSManagedObjectID? {
        didSet {
            updateSelectedItemLayout(animated: true)
        }
    }

    private var lastLayoutWidth: CGFloat = 0

    private var isUserInteracting: Bool {
        collectionView.isTracking || collectionView.isDragging || collectionView.isDecelerating
    }

    // MARK: - Subviews

    private lazy var layout: MediaBrowserPageStripLayout = {
        let layout = MediaBrowserPageStripLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = Configuration.itemSize
        layout.minimumLineSpacing = Configuration.itemSpacing
        // Square
        layout.selectedItemWidth = Configuration.itemSize.height
        layout.selectedItemSpacing = Configuration.selectedItemSpacing
        return layout
    }()

    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.delegate = self
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.decelerationRate = .fast
        collectionView.registerCell(MediaBrowserPageStripCell.self)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()

    private lazy var dataSource = UICollectionViewDiffableDataSource<Section, NSManagedObjectID>(
        collectionView: collectionView
    ) { [weak self] collectionView, indexPath, objectID in
        let cell: MediaBrowserPageStripCell = collectionView.dequeueCell(for: indexPath)
        cell.thumbnailImage = self?.mediaManager.thumbnailDisplayMessage(for: objectID)?.thumbnailImage
        return cell
    }

    // MARK: - Lifecycle

    init(mediaManager: MediaBrowserMediaManager) {
        self.mediaManager = mediaManager

        super.init(frame: .zero)

        // VoiceOver users page with the pager itself
        accessibilityElementsHidden = true

        addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: Configuration.itemSize.height),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // The first and last items must be able to scroll to the center
        let width = bounds.width
        guard width > 0, width != lastLayoutWidth else {
            return
        }
        lastLayoutWidth = width

        let inset = max((width - Configuration.itemSize.width) / 2, 0)
        layout.sectionInset = UIEdgeInsets(top: 0, left: inset, bottom: 0, right: inset)
        layout.invalidateLayout()
        collectionView.layoutIfNeeded()

        scrollToSelectedObject(animated: false)
    }

    // MARK: - Public functions

    func apply(objectIDs: [NSManagedObjectID], reconfigureIDs: [NSManagedObjectID]) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, NSManagedObjectID>()
        snapshot.appendSections([.main])
        snapshot.appendItems(objectIDs, toSection: .main)
        snapshot.reconfigureItems(reconfigureIDs)

        dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
            self?.updateSelectedItemLayout(animated: false)
            self?.scrollToSelectedObject(animated: false)
        }
    }

    /// Only scrolls to the item if the user is not interacting with the strip
    func select(_ objectID: NSManagedObjectID?, animated: Bool) {
        selectedObjectID = objectID

        guard !isUserInteracting else {
            return
        }

        scrollToSelectedObject(animated: animated)
    }

    // MARK: - Private functions

    private func updateSelectedItemLayout(animated: Bool) {
        let selectedItem = selectedObjectID.flatMap { dataSource.indexPath(for: $0)?.item }
        guard selectedItem != layout.selectedItem else {
            return
        }

        guard animated, window != nil else {
            layout.selectedItem = selectedItem
            return
        }

        UIView.animate(withDuration: Configuration.selectionAnimationDuration) {
            self.layout.selectedItem = selectedItem
            self.collectionView.layoutIfNeeded()
        }
    }

    private func scrollToSelectedObject(animated: Bool) {
        guard let selectedObjectID, let indexPath = dataSource.indexPath(for: selectedObjectID) else {
            return
        }

        collectionView.setContentOffset(contentOffset(forItemAt: indexPath.item), animated: animated)
    }

    /// Centers the item
    private func contentOffset(forItemAt item: Int) -> CGPoint {
        CGPoint(x: CGFloat(item) * (Configuration.itemSize.width + Configuration.itemSpacing), y: 0)
    }

    /// Closest to the center
    private func item(forContentOffset contentOffset: CGPoint) -> Int? {
        let itemCount = collectionView.numberOfSections > 0 ? collectionView.numberOfItems(inSection: 0) : 0
        
        guard itemCount > 0 else {
            return nil
        }

        let item = Int((contentOffset.x / (Configuration.itemSize.width + Configuration.itemSpacing)).rounded())
        return min(max(item, 0), itemCount - 1)
    }

    private func selectItemFromUser(at item: Int) {
        guard let objectID = dataSource.itemIdentifier(for: IndexPath(item: item, section: 0)),
              objectID != selectedObjectID else {
            return
        }

        selectedObjectID = objectID
        onSelect?(objectID)
    }

    // MARK: - UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)
        selectItemFromUser(at: indexPath.item)
        scrollToSelectedObject(animated: true)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard isUserInteracting, let item = item(forContentOffset: scrollView.contentOffset) else {
            return
        }

        selectItemFromUser(at: item)
    }

    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        guard let item = item(forContentOffset: targetContentOffset.pointee) else {
            return
        }

        targetContentOffset.pointee = contentOffset(forItemAt: item)
    }
}

// MARK: - MediaBrowserPageStripLayout

/// Widens the selected item and moves its neighbors away. The centers of all other items stay where a uniform layout
/// puts them, so the content offsets of the items do not change.
private final class MediaBrowserPageStripLayout: UICollectionViewFlowLayout {

    var selectedItemWidth: CGFloat = 0
    var selectedItemSpacing: CGFloat = 0

    var selectedItem: Int? {
        didSet {
            if selectedItem != oldValue {
                invalidateLayout()
            }
        }
    }

    private var neighborOffset: CGFloat {
        (selectedItemWidth - itemSize.width) / 2 + selectedItemSpacing
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        // Moved items might come into the rect
        super.layoutAttributesForElements(in: rect.insetBy(dx: -neighborOffset, dy: 0))?.map(adjusted)
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        super.layoutAttributesForItem(at: indexPath).map(adjusted)
    }

    private func adjusted(_ attributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        guard let selectedItem, let adjusted = attributes.copy() as? UICollectionViewLayoutAttributes else {
            return attributes
        }

        let item = attributes.indexPath.item
        if item == selectedItem {
            adjusted.size.width = selectedItemWidth
        }
        else {
            adjusted.center.x += item < selectedItem ? -neighborOffset : neighborOffset
        }
        return adjusted
    }
}
