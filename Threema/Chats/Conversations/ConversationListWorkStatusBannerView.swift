import ThreemaMacros
import UIKit

/// Displays the own status in a colored box. The whole banner is tappable to change the status.
final class ConversationListWorkStatusBannerView: UIView {
    
    // MARK: - Config

    private enum Configuration {
        static let roundedRectVerticalInset: CGFloat = 12
        static let roundedRectHorizontalInset: CGFloat = 16
        
        static let containerVerticalInset: CGFloat = 12
        static let containerHorizontalInset: CGFloat = 16
        
        static let imageSize: CGFloat = 24
        
        static let stackViewSpacing: CGFloat = 12

        static let editPillVerticalInset: CGFloat = 6
        static let editPillHorizontalInset: CGFloat = 12
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
    
    private lazy var editPillLabel: UILabel = {
        let label = UILabel()
        label.text = #localize("edit")
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// Mimics the appearance of a small bordered button, but is not a control. The edit action is handled by a
    /// tap gesture on the whole banner
    private lazy var editPillView: UIView = {
        let view = UIView()
        view.backgroundColor = .labelInverted
        view.layer.masksToBounds = true
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        view.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(editPillLabel)
        NSLayoutConstraint.activate([
            editPillLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: Configuration.editPillVerticalInset),
            editPillLabel.bottomAnchor.constraint(
                equalTo: view.bottomAnchor,
                constant: -Configuration.editPillVerticalInset
            ),
            editPillLabel.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: Configuration.editPillHorizontalInset
            ),
            editPillLabel.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -Configuration.editPillHorizontalInset
            ),
        ])

        return view
    }()
    
    /// The whole banner is the tap target instead of a dedicated button (see `editPillView`).
    ///
    /// The recognizer is attached to the *window* (see `didMoveToWindow()`), not the banner: in the iPad split
    /// view sidebar, the system's interactive column-resize separator overlaps the banner's trailing area and
    /// wins the hit-test, so touches there are never delivered to the banner's own recognizers. A recognizer
    /// on the window receives every touch in the window; the delegate filters it to touches inside the banner.
    /// `cancelsTouchesInView = false` keeps the separator's drag-to-resize fully functional – a drag fails the
    /// tap recognizer anyway, so only actual taps trigger the edit action.
    private lazy var tapGestureRecognizer: UITapGestureRecognizer = {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tapGestureRecognizer.cancelsTouchesInView = false
        tapGestureRecognizer.delegate = self
        return tapGestureRecognizer
    }()

    // MARK: - Callbacks
    
    private let editButtonTapped: () -> Void
    
    // MARK: - Initialization
    
    init(status: WorkAvailabilityStatus, editButtonTapped: @escaping () -> Void) {
        self.status = status
        self.editButtonTapped = editButtonTapped
        
        super.init(frame: .zero)
        
        setupView()
        updateView()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func didMoveToWindow() {
        super.didMoveToWindow()

        // (Re)attach the tap recognizer to the current window, detaching it from any previous one
        tapGestureRecognizer.view?.removeGestureRecognizer(tapGestureRecognizer)
        window?.addGestureRecognizer(tapGestureRecognizer)
    }

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

        // Capsule shape for the (decorative) edit pill
        editPillView.layer.cornerRadius = editPillView.bounds.height / 2
    }

    // MARK: - Accessibility

    override func accessibilityActivate() -> Bool {
        editButtonTapped()
        return true
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

        // Accessibility: announce the current status on the banner-wide button
        accessibilityLabel = textLabel.text
    }

    @objc private func handleTap() {
        editButtonTapped()
    }
    
    private func setupView() {
        backgroundColor = nil
        
        // Expose the banner as a single button to assistive technologies
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityHint = #localize("edit_work_availability")

        // Add arranged subviews to stack
        if !traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            stackView.addArrangedSubview(imageView)
        }
        stackView.addArrangedSubview(textLabel)
        stackView.addArrangedSubview(editPillView)
        
        // Add rounded container to main view
        addSubview(roundedContainer)
        NSLayoutConstraint.activate([
            roundedContainer.topAnchor.constraint(equalTo: topAnchor, constant: 0),
            roundedContainer.leadingAnchor.constraint(
                equalTo: safeAreaLayoutGuide.leadingAnchor,
                constant: Configuration.containerHorizontalInset
            ),
            roundedContainer.trailingAnchor.constraint(
                equalTo: safeAreaLayoutGuide.trailingAnchor,
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

// MARK: - UIGestureRecognizerDelegate

extension ConversationListWorkStatusBannerView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // The recognizer lives on the window and would otherwise see every touch:
        // only accept touches that land inside the banner
        bounds.contains(touch.location(in: self))
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // Allow the banner tap to fire even while another recognizer (sidebar resize, table view) is tracking
        true
    }
}

#Preview {
    let view = ConversationListWorkStatusBannerView(
        status: WorkAvailabilityStatus(category: .unavailable, text: "I'm no vacation. 🏝️")
    ) {
        // no-op
    }
    
    // Needed to add rounded corners to Edit-"Button"
    view.setNeedsLayout()
    view.layoutIfNeeded()
    
    return view
}
