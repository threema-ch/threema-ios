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

final class SelectContactListHeaderViewLayout: UICollectionViewLayout {
    // MARK: Constants

    private enum Constants {
        static var visibleItems: CGFloat {
            UIDevice.current.userInterfaceIdiom == .pad ? 6 : 4
        }

        static let minHeight: CGFloat = 40
        static let spacing: CGFloat = 16
        static let sectionInset = NSDirectionalEdgeInsets(
            top: 0,
            leading: 20,
            bottom: 6,
            trailing: 20
        )
    }

    // MARK: Public properties

    weak var delegate: ContactSelectionHandler?
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
        let horizontalInset = Constants.sectionInset.leading + Constants.sectionInset.trailing
        let availableWidth = viewportWidth - horizontalInset
        let itemWidth = max(
            0,
            (availableWidth - ((Constants.visibleItems - 1) * Constants.spacing)) / Constants.visibleItems
        )
        
        let sizingCell = ContactGridContactCell(
            frame: CGRect(x: 0, y: 0, width: itemWidth, height: 1000)
        )
        
        var xOffset = Constants.sectionInset.leading
        var maxHeight: CGFloat = 0

        for item in 0..<collectionView.numberOfItems(inSection: 0) {
            let indexPath = IndexPath(item: item, section: 0)
            let contact = delegate.selectedItems()[indexPath.row]
            let targetSize = CGSize(width: itemWidth, height: UIView.layoutFittingCompressedSize.height)
            
            sizingCell.configureForSizing(with: contact.attributedDisplayName)
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
