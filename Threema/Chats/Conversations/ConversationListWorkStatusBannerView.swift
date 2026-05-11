import ThreemaMacros
import UIKit

/// Displays the own status in a colored box with a button to change it.
final class ConversationListWorkStatusBannerView: UIView {
    
    // MARK: - Config

    private enum Configuration {
        static let roundedRectVerticalInset: CGFloat = 12
        static let roundedRectHorizontalInset: CGFloat = 16
        
        static let containerVerticalInset: CGFloat = 12
        static let containerHorizontalInset: CGFloat = 16
        
        static let imageSize: CGFloat = 24
        
        static let stackViewSpacing: CGFloat = 12
    }
    
    // MARK: - Properties

    var status: WorkAvailabilityStatus {
        didSet {
            updateView()
        }
    }
    
    private lazy var roundedContainer: UIView = {
        let view = UIView()
        view.layer.masksToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            stackView.axis = .vertical
        }
        else {
            stackView.axis = .horizontal
        }
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.spacing = Configuration.stackViewSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure image size
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: Configuration.imageSize),
            imageView.heightAnchor.constraint(equalToConstant: Configuration.imageSize),
        ])
        
        return imageView
    }()
    
    private lazy var textLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 1 // Own status is limited to one line only
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()
    
    private lazy var actionButton: UIButton = {
        var buttonConfig = UIButton.Configuration.bordered()
        buttonConfig.title = #localize("edit")
        buttonConfig.buttonSize = .small
        buttonConfig.baseBackgroundColor = .labelInverted
        buttonConfig.baseForegroundColor = .label
        
        let button = UIButton(configuration: buttonConfig)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.accessibilityLabel = #localize("edit_work_availability")
        
        let action = UIAction { [weak self] _ in
            self?.editButtonTapped()
        }
        button.addAction(action, for: .touchUpInside)
        
        return button
    }()
    
    // MARK: - Callbacks
    
    private let editButtonTapped: () -> Void
    
    // MARK: - Initialization
    
    init(status: WorkAvailabilityStatus, editButtonTapped: @escaping () -> Void) {
        self.status = status
        self.editButtonTapped = editButtonTapped
        
        super.init(frame: .zero)
        
        setupView()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if #available(iOS 26.0, *) {
            // Use capsule shape
            roundedContainer.cornerConfiguration = .uniformCorners(
                radius: UICornerRadius(floatLiteral: 30)
            )
        }
        else {
            // Use fixed corner radius for older iOS versions
            roundedContainer.layer.cornerRadius = 12
        }
    }
    
    // MARK: - Setup
    
    private func updateView() {
        // Image
        imageView.image = UIImage(systemName: status.category.systemImageName)
        imageView.tintColor = status.category.color
        
        // Text
        textLabel.text = status.text != nil ? status.text : status.category.localizedDescription

        // Color
        roundedContainer.backgroundColor = status.category.bannerColor
    }
    
    private func setupView() {
        backgroundColor = nil
        
        // Add arranged subviews to stack
        if !traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            stackView.addArrangedSubview(imageView)
        }
        stackView.addArrangedSubview(textLabel)
        stackView.addArrangedSubview(actionButton)
        
        // Add rounded container to main view
        addSubview(roundedContainer)
        NSLayoutConstraint.activate([
            roundedContainer.topAnchor.constraint(equalTo: topAnchor, constant: 0),
            roundedContainer.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: Configuration.containerHorizontalInset
            ),
            roundedContainer.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -Configuration.containerHorizontalInset
            ),
            roundedContainer.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -Configuration.containerVerticalInset
            ),
        ])
        
        // Add stack view inside rounded container
        roundedContainer.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(
                equalTo: roundedContainer.topAnchor,
                constant: Configuration.roundedRectVerticalInset
            ),
            stackView.leadingAnchor.constraint(
                equalTo: roundedContainer.leadingAnchor,
                constant: Configuration.roundedRectHorizontalInset
            ),
            stackView.trailingAnchor.constraint(
                equalTo: roundedContainer.trailingAnchor,
                constant: -Configuration.roundedRectHorizontalInset
            ),
            stackView.bottomAnchor.constraint(
                equalTo: roundedContainer.bottomAnchor,
                constant: -Configuration.roundedRectVerticalInset
            ),
        ])
    }
}
