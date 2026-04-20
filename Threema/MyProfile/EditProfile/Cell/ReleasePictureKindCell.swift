import UIKit

final class ReleasePictureKindCell: UICollectionViewListCell {

    // MARK: - Configuration
    
    func configure(with label: String, isChecked: Bool) {
        var content = defaultContentConfiguration()
        content.text = label
        let checkmarkAccessory = UICellAccessory.checkmark(
            options: .init(isHidden: !isChecked, reservedLayoutWidth: .actual)
        )

        contentConfiguration = content
        accessories = [checkmarkAccessory]
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        accessories = []
        contentConfiguration = nil
    }
}

// MARK: - Reusable

extension ReleasePictureKindCell: Reusable { }
