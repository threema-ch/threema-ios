import Foundation
import ThreemaMacros

final class PlusButtonCollectionViewCell: UICollectionViewCell {
    @IBOutlet var imageView: UIImageView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupTraitRegistration()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTraitRegistration()
    }
    
    func setup() {
        contentView.backgroundColor = .secondary
        imageView.image = UIImage(systemName: "plus")?.applying(symbolWeight: .semibold, symbolScale: .large)
            .withTintColor(.primary)

        layer.borderWidth = 2
        layer.cornerRadius = 5
        layer.borderColor = UIColor.systemGroupedBackground.cgColor
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        setup()
    }

    override var isAccessibilityElement: Bool {
        set { }
        get {
            true
        }
    }

    override var accessibilityLabel: String? {
        set { }
        get {
            #localize("media_preview_accessibility_plus_button")
        }
    }

    // MARK: - Helpers

    private func setupTraitRegistration() {
        let traits: [UITrait] = [UITraitUserInterfaceStyle.self]
        registerForTraitChanges(traits) { [weak self] (_: Self, previous) in
            guard let self else {
                return
            }
            if previous.userInterfaceStyle != traitCollection.userInterfaceStyle {
                // CGColors have no automatic theme change built in, so we track it ourselves
                layer.borderColor = UIColor.systemGroupedBackground.cgColor
            }
        }
    }
}
