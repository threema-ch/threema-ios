import Foundation

class ScreenWidthSizedCell: UICollectionViewCell {
    // Adjust the systemLayoutSizeFitting to be <= the screen width
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
        
        size.width = min(targetSize.width, UIScreen.main.bounds.width)
        return size
    }
}
