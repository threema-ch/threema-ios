import ThreemaMacros
import UIKit

final class ContactGridAddButtonCell: UICollectionViewCell {
    
    // MARK: - Constants
    
    private enum Constants {
        static let spacing: CGFloat = 8
    }
    
    // MARK: - Properties
    
    var onTap: (() -> Void)?
    
    // MARK: - Subviews
    
    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        
        let image = UIImage(systemName: "plus")?.applying(symbolWeight: .semibold, symbolScale: .large)
        imageView.image = image
        imageView.contentMode = .scaleAspectFill
        imageView.tintColor = .tintColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var iconBackgroundView: UIView = {
        let view = UIView()
        
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .secondary
        view.layer.masksToBounds = true
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        view.contentMode = .top
        
        return view
    }()
    
    private lazy var addLabel: UILabel = {
        let label = UILabel()
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .vertical)
        label.numberOfLines = 2
        label.textAlignment = .center
        label.contentMode = .top
        label.font = .preferredFont(forTextStyle: .caption1)
        label.textColor = .tintColor
        label.adjustsFontForContentSizeCategory = true
        label.text = #localize("add_button")
        return label
    }()
    
    private lazy var stackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [iconBackgroundView, addLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Constants.spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var tapRecognizer: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(iconTapped))
        return recognizer
    }()
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        stackView.addGestureRecognizer(tapRecognizer)
        stackView.isUserInteractionEnabled = true
        
        contentView.addSubview(stackView)
        
        iconBackgroundView.addSubview(iconImageView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor),
            
            iconBackgroundView.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            iconBackgroundView.heightAnchor.constraint(equalTo: iconBackgroundView.widthAnchor),
            
            iconImageView.centerXAnchor.constraint(equalTo: iconBackgroundView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconBackgroundView.centerYAnchor),
        ])
        
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = #localize("accessibility_add_contact")
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        iconBackgroundView.layoutIfNeeded()
        iconBackgroundView.layer.cornerRadius = iconBackgroundView.frame.height / 2
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        onTap = nil
    }
    
    // MARK: - Actions
    
    @objc private func iconTapped() {
        onTap?()
    }
}

// MARK: - Reusable

extension ContactGridAddButtonCell: Reusable { }
