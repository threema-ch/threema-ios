import UIKit

final class SelectedItemsHeaderViewLayout: UICollectionViewLayout {
    // MARK: Constants

    private enum Constants {
        static var visibleItems: CGFloat {
            UIDevice.current.userInterfaceIdiom == .pad ? 6 : 4
        }

        static let minHeight: CGFloat = 40
        static let spacing: CGFloat = 16
        static let sectionInset = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 6, trailing: 20)
    }

    // MARK: Public properties

    weak var delegate: ItemSelectionHandler?
    var reportSizeChange: () -> Void = { }

    override var flipsHorizontallyInOppositeLayoutDirection: Bool {
        true
    }

    // MARK: Private properties

    private var cachedAttributes: [UICollectionViewLayoutAttributes] = []
    private var contentSize: CGSize = .zero {
        didSet {
            if oldValue != contentSize {
                reportSizeChange()
            }
        }
    }

    // MARK: Lifecycle

    // MARK: Layout functions

    override func prepare() {
        super.prepare()
        guard let collectionView, let delegate else {
            return
        }
        
        guard collectionView.numberOfSections > 0 else {
            return
        }

        cachedAttributes.removeAll()
        
        let viewportWidth = collectionView.bounds.width

        let windowMinimumDimension = min(
            collectionView.window?.bounds.width ?? 0,
            collectionView.window?.bounds.height ?? 0
        ) * 0.8

        let horizontalInset = Constants.sectionInset.leading + Constants.sectionInset.trailing

        // Consider minimum from both dimensions, for fitting landscape size
        let availableWidth = min(viewportWidth - horizontalInset, windowMinimumDimension)
        let itemWidth = max(
            0,
            (availableWidth - ((Constants.visibleItems - 1) * Constants.spacing)) / Constants.visibleItems
        )
        
        let sizingCell = SelectedItemGridCell(
            frame: CGRect(x: 0, y: 0, width: itemWidth, height: 1000)
        )
        
        var xOffset = Constants.sectionInset.leading
        var maxHeight: CGFloat = 0

        for item in 0..<collectionView.numberOfItems(inSection: 0) {
            let indexPath = IndexPath(item: item, section: 0)
            let item = delegate.selectedItems()[indexPath.row]
            let targetSize = CGSize(width: itemWidth, height: UIView.layoutFittingCompressedSize.height)

            switch item.item {
            case let .contact(contact):
                sizingCell.configureForSizing(with: contact.attributedDisplayName)

            case let .group(group):
                sizingCell.configureForSizing(with: group.attributedDisplayName)

            case let .distributionList(list):
                sizingCell.configureForSizing(with: list.attributedDisplayName)
            }

            let size = sizingCell.systemLayoutSizeFitting(
                targetSize,
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            )
            
            let height = ceil(max(size.height, Constants.minHeight))
            let frame = CGRect(x: xOffset, y: Constants.sectionInset.top, width: itemWidth, height: height)
            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attributes.frame = frame
            
            cachedAttributes.append(attributes)

            xOffset += itemWidth + Constants.spacing
            maxHeight = max(maxHeight, height)
        }

        contentSize = CGSize(
            width: xOffset + Constants.sectionInset.trailing - Constants.spacing,
            height: maxHeight + Constants.sectionInset.top + Constants.sectionInset.bottom
        )
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        cachedAttributes.filter { $0.frame.intersects(rect) }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        cachedAttributes.first { $0.indexPath == indexPath }
    }

    override var collectionViewContentSize: CGSize {
        contentSize
    }
}
