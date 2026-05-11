import ThreemaMacros
import TipKit
import UIKit

/// Displays a contact's work availability status in the chat view (read-only)
final class ChatViewWorkStatusBannerView: UIView {
    
    // MARK: - Config
    
    private let roundedRectVerticalInset: CGFloat = 0
    private let roundedRectHorizontalInset: CGFloat = 8

    private let containerVerticalInset: CGFloat = 12
    private let containerHorizontalInset: CGFloat = 16
    private let collapsedLineLimit = 2
        
    // MARK: - Properties
    
    private let contact: Contact
    
    private var statusObserver: NSKeyValueObservation?
    
    private var isExpanded = false
    
    private lazy var tapGestureRecognizer: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        return recognizer
    }()
    
    private lazy var effectBackgroundView: UIVisualEffectView = {
        let effect: UIVisualEffect =
            if #available(iOS 26.0, *) {
                UIGlassEffect(style: .regular)
            }
            else {
                UIBlurEffect(style: .systemMaterial)
            }
     
        let view = UIVisualEffectView(effect: effect)
        view.layer.masksToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
       
        if #available(iOS 26.0, *) {
            view.cornerConfiguration = .uniformCorners(
                radius: UICornerRadius(floatLiteral: 30)
            )
        }
        else {
            view.layer.cornerRadius = 12
        }
        view.addGestureRecognizer(tapGestureRecognizer)
        
        return view
    }()
    
    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private lazy var textLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.maximumContentSizeCategory = .extraExtraExtraLarge
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = collapsedLineLimit
        label.textAlignment = .center
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()
    
    private lazy var expandImage: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "chevron.down.circle")
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .body)
        imageView.maximumContentSizeCategory = .extraExtraExtraLarge
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .label
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        return imageView
    }()
    
    private var tipObservationTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(contact: Contact, bounds: CGRect) {
        self.contact = contact
        super.init(frame: .zero)
        
        updateView()
        configureView(bounds: bounds)
        observeContact()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
        
    deinit {
        statusObserver?.invalidate()
    }
    
    // MARK: - Observation
    
    private func observeContact() {
        statusObserver = contact.observe(\.workAvailabilityStatus, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor in
                self?.updateView()
            }
        }
    }
    
    // MARK: - Setup
    
    private func configureView(bounds: CGRect) {
        backgroundColor = nil
        
        // Add text label to stack view
        stackView.addArrangedSubview(textLabel)
        
        // Expand image
        if textLabel.exceeds(lines: collapsedLineLimit, availableWidth: bounds.width) {
            stackView.addArrangedSubview(expandImage)
        }
        
        // Add background
        addSubview(effectBackgroundView)
        NSLayoutConstraint.activate([
            effectBackgroundView.topAnchor.constraint(equalTo: topAnchor, constant: roundedRectVerticalInset),
            effectBackgroundView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: roundedRectHorizontalInset),
            effectBackgroundView.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -roundedRectHorizontalInset
            ),
            effectBackgroundView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -roundedRectVerticalInset),
        ])
        
        // Add stack view
        effectBackgroundView.contentView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(
                equalTo: effectBackgroundView.contentView.topAnchor,
                constant: containerVerticalInset
            ),
            stackView.leadingAnchor.constraint(
                equalTo: effectBackgroundView.contentView.leadingAnchor,
                constant: containerHorizontalInset
            ),
            stackView.trailingAnchor.constraint(
                equalTo: effectBackgroundView.contentView.trailingAnchor,
                constant: -containerHorizontalInset
            ),
            stackView.bottomAnchor.constraint(
                equalTo: effectBackgroundView.contentView.bottomAnchor,
                constant: -containerVerticalInset
            ),
        ])
    }
    
    // MARK: - Update
    
    private func updateView() {
        guard let status = contact.workAvailabilityStatus else {
            isHidden = true
            return
        }
        
        // Update text
        textLabel.text = status.text ?? status.category.localizedDescription
        textLabel.text = textLabel.text
        textLabel.accessibilityLabel = status.accessibilityLabelWithText
        
        // Update background color based on iOS version
        if #available(iOS 26.0, *), let glassEffect = effectBackgroundView.effect as? UIGlassEffect {
            glassEffect.tintColor = status.category.bannerColor
            effectBackgroundView.effect = glassEffect
        }
        else {
            effectBackgroundView.backgroundColor = status.category.bannerColor
        }

        // Update visibility
        isHidden = status.category == .none
    }
    
    @objc private func handleTap() {
        
        if isExpanded {
            textLabel.numberOfLines = collapsedLineLimit
            expandImage.image = UIImage(systemName: "chevron.down.circle")
        }
        else {
            textLabel.numberOfLines = 0
            expandImage.image = UIImage(systemName: "chevron.up.circle")
        }
        
        isExpanded.toggle()
    }
    
    // MARK: - TipKit
    
    func showTipIfNeeded(in containerView: UIView) {
        guard !ProcessInfoHelper.isRunningForScreenshots else {
            return
        }
        
        guard !isHidden else {
            return
        }

        guard !UIAccessibility.isVoiceOverRunning else {
            return
        }
        
        guard ThreemaEnvironment.workAvailabilityStatusEnabled else {
            return
        }
        
        let threemaWorkAvailabilityStatusTip = TipKitManager.ThreemaWorkAvailabilityStatusChatTip(forChat: true)
        let threemaWorkAvailabilityStatusTipView = TipUIView(threemaWorkAvailabilityStatusTip, arrowEdge: .top)
        threemaWorkAvailabilityStatusTipView.translatesAutoresizingMaskIntoConstraints = false

        tipObservationTask = tipObservationTask ?? Task(priority: .userInitiated) { @MainActor in
            for await shouldDisplay in threemaWorkAvailabilityStatusTip.shouldDisplayUpdates {
                if shouldDisplay {
                    // We add to the correct container for the close button to work
                    containerView.addSubview(threemaWorkAvailabilityStatusTipView)

                    NSLayoutConstraint.activate([
                        threemaWorkAvailabilityStatusTipView.topAnchor
                            .constraint(equalTo: bottomAnchor),
                        threemaWorkAvailabilityStatusTipView.leadingAnchor
                            .constraint(greaterThanOrEqualTo: stackView.leadingAnchor),
                        threemaWorkAvailabilityStatusTipView.trailingAnchor
                            .constraint(lessThanOrEqualTo: stackView.trailingAnchor),
                        threemaWorkAvailabilityStatusTipView.centerXAnchor
                            .constraint(equalTo: centerXAnchor),
                    ])
                }
                else {
                    threemaWorkAvailabilityStatusTipView.removeFromSuperview()
                }
            }
        }
    }
}
