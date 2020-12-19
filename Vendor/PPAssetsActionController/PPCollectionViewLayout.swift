import UIKit

/**
 Custom layout that allows for smooth resize animation.
 */
class PPCollectionViewLayout: UICollectionViewLayout {
    public var viewWidth: CGFloat = 0.0
    public var spacing: CGFloat = 6.0
    public weak var itemsInfoProvider: (UICollectionViewDataSource & UICollectionViewDelegateFlowLayout)!

    private var attributes: [UICollectionViewLayoutAttributes] = []
    private var contentSize = CGSize.zero

    override func prepare() {
        super.prepare()

        attributes = []

        var origin = CGPoint()
        let itemsCount = itemsInfoProvider.collectionView(collectionView!, numberOfItemsInSection: 0)

        for index in 0..<itemsCount {
            let indexPath = IndexPath(item: index, section: 0)
            let itemAttributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            let size = itemsInfoProvider.collectionView!(collectionView!, layout: self, sizeForItemAt: indexPath)
            itemAttributes.frame = CGRect(origin: origin, size: size)
            attributes.append(itemAttributes)
            origin.x = itemAttributes.frame.maxX + spacing
        }

        contentSize = CGSize(width: origin.x - spacing, height: origin.y)
    }
    
    override var collectionViewContentSize: CGSize {
        return contentSize
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var layoutAttributes: [UICollectionViewLayoutAttributes] = []
        
        for itemAttributes in attributes {
            if (rect.intersects(itemAttributes.frame) == true) {
                layoutAttributes.append(itemAttributes)
            }
        }
        
        return layoutAttributes
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        if (attributes.count > indexPath.row) {
            return attributes[indexPath.row]
        } else {
            return nil
        }
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return false
    }

}
