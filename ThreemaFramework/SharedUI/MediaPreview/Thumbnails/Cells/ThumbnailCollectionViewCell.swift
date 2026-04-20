import UIKit

final class ThumbnailCollectionViewCell: UICollectionViewCell {
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!

    var identifier: IndexPath?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupTraitRegistration()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTraitRegistration()
    }
    
    override var isSelected: Bool {
        didSet {
            updateSelectionState()
        }
    }
    
    func updateSelectionState() {
        layer.borderColor = isSelected ? UIColor.primary.resolvedColor(with: traitCollection).cgColor : Colors
            .backgroundView.resolvedColor(with: traitCollection).cgColor
    }
    
    override func prepareForReuse() {
        imageView.image = nil
        startLoading()
        isSelected = false
        updateSelectionState()
    }
    
    func setColors() {
        backgroundColor = .secondarySystemGroupedBackground
        layer.borderWidth = 2
        layer.cornerRadius = 5
        if isSelected {
            layer.borderColor = UIColor.primary.resolvedColor(with: traitCollection).cgColor
        }
        else {
            layer.borderColor = Colors.backgroundView.resolvedColor(with: traitCollection).cgColor
        }
    }
    
    func startLoading() {
        setColors()

        activityIndicator.startAnimating()
        
        imageView.isHidden = true
        activityIndicator.isHidden = false
    }
    
    func loadImage(image: UIImage) {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        
        imageView.image = image
        activityIndicator.stopAnimating()
        
        imageView.isHidden = false
        activityIndicator.isHidden = true
    }
    
    override var isAccessibilityElement: Bool {
        set { }
        get {
            false
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
                updateSelectionState()
            }
        }
    }
}
