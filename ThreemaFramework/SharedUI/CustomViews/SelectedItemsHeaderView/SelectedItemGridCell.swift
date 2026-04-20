import ThreemaMacros

public final class SelectedItemGridCell: UICollectionViewCell {

    // MARK: - Constants
    
    private enum Constants {
        static let spacing: CGFloat = 8
    }
    
    // MARK: - Private properties
    
    public var onClear: (() -> Void)?

    // MARK: - Private properties
    
    private lazy var clearButton: OpaqueDeleteButton = {
        let button = OpaqueDeleteButton { [weak self] _ in
            self?.onClear?()
        }
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var profileImageView: ProfilePictureImageView = {
        let imageView = ProfilePictureImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentHuggingPriority(.required, for: .vertical)
        imageView.setContentCompressionResistancePriority(.required, for: .vertical)
        imageView.contentMode = .top
        return imageView
    }()

    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .vertical)
        label.numberOfLines = 2
        label.textAlignment = .center
        label.contentMode = .top
        label.font = .preferredFont(forTextStyle: .caption1)
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    private lazy var stackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [profileImageView, nameLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Constants.spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // MARK: - Accessibility
    
    override public var isAccessibilityElement: Bool {
        get { true }
        set { }
    }

    override public var accessibilityLabel: String? {
        get { nameLabel.text }
        set { }
    }

    override public var accessibilityTraits: UIAccessibilityTraits {
        get { [.button] }
        set { }
    }

    override public var accessibilityCustomActions: [UIAccessibilityCustomAction]? {
        get {
            guard onClear != nil else {
                return nil
            }

            return [
                UIAccessibilityCustomAction(
                    name: #localize("accessibility_remove_contact"),
                    target: self,
                    selector: #selector(accessibilityRemoveContact)
                ),
            ]
        }
        set { }
    }

    @objc private func accessibilityRemoveContact() -> Bool {
        onClear?()
        return true
    }

    // MARK: - Lifecycle
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        
        contentView.addSubview(stackView)
        contentView.addSubview(clearButton)

        NSLayoutConstraint.activate([
            clearButton.topAnchor.constraint(equalTo: contentView.topAnchor),
            clearButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 8),

            profileImageView.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            profileImageView.heightAnchor.constraint(equalTo: profileImageView.widthAnchor),

            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func prepareForReuse() {
        super.prepareForReuse()
        onClear = nil
    }
    
    // MARK: - Configuration
    
    public func configureForSizing(with text: NSAttributedString) {
        nameLabel.attributedText = text
    }

    public func configure(for item: SelectableItem) {
        switch item.item {
        case let .contact(contact):
            nameLabel.attributedText = contact.attributedDisplayName
            profileImageView.info = .contact(contact)

        case let .group(group):
            nameLabel.attributedText = group.attributedDisplayName
            profileImageView.info = .group(group)

        case let .distributionList(list):
            nameLabel.attributedText = list.attributedDisplayName
            profileImageView.info = .distributionList(list)
        }
    }
}

// MARK: - Reusable

extension SelectedItemGridCell: Reusable { }
