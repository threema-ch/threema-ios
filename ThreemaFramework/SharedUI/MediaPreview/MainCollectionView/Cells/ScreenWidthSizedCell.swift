import Foundation

class ScreenWidthSizedCell: UICollectionViewCell {
    // Adjust the systemLayoutSizeFitting to be <= the width of the collection view displaying the cell
    override func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        var size = super.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        
        size.width = min(targetSize.width, superview?.bounds.width ?? targetSize.width)
        return size
    }
}
