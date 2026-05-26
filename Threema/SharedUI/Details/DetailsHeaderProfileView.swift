import CocoaLumberjackSwift
import ThreemaFramework
import TipKit
import UIKit

// MARK: - DetailsHeaderProfileView.Configuration

extension DetailsHeaderProfileView {
    struct Configuration: DetailsConfiguration {
        /// Show debug background colors
        let debug = false
        
        let defaultSpacing: CGFloat = 8
        
        let customSpacingAfterProfilePicture: CGFloat = 10

        let verificationLevelHeight: CGFloat = 12
        
        let collapsedLineLimit = 2
    }
}

final class DetailsHeaderProfileView: UIStackView {
    
    /// Entity agnostic header configuration
    struct ContentConfiguration {
        /// Info for profile picture view
        let profilePictureInfo: ProfilePictureImageView.Info
        /// Name shown
        let name: String
        /// Provide image for verification level if any
        let verificationLevelImage: UIImage?
        /// Provide accessibility description for verification level if any.
        /// This should be set if `verificationLevelImage` is not `nil`.
        let verificationLevelAccessibilityLabel: String?
        /// Provides availabilityStatus in case of configuration of a contact profile.
        let availabilityStatus: WorkAvailabilityStatus?
        /// Provides bool if user is member of the group
        let isSelfMember: Bool
        
        init(
            profilePictureInfo: ProfilePictureImageView.Info,
            name: String,
            verificationLevelImage: UIImage? = nil,
            verificationLevelAccessibilityLabel: String? = nil,
            availabilityStatus: WorkAvailabilityStatus? = nil,
            isSelfMember: Bool = true
        ) {
            self.profilePictureInfo = profilePictureInfo
            self.name = name
            self.verificationLevelImage = verificationLevelImage
            self.verificationLevelAccessibilityLabel = verificationLevelAccessibilityLabel
            self.availabilityStatus = availabilityStatus
            self.isSelfMember = isSelfMember
        }
    }
    
    var contentConfiguration: ContentConfiguration {
        didSet {
            updateContent()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if isAvailabilityStatusVisible {
            if availabilityStatusLabel.exceeds(
                lines: DetailsHeaderProfileView.configuration.collapsedLineLimit,
                availableWidth: bounds.width
            ) {
                availabilityStatusExpandImage.isHidden = false
            }
            else {
                availabilityStatusExpandImage.isHidden = true
            }
            
            if #available(iOS 26.0, *) {
                availabilityStatusView.cornerConfiguration = .uniformCorners(
                    radius: UICornerRadius(floatLiteral: 30)
                )
            }
            else {
                availabilityStatusView.layer.cornerRadius = 12
            }
        }
    }

    // MARK: - Private properties
    
    private static let configuration = Configuration()

    // We need to hold on to the observers until this object is deallocated.
    // `invalidate()` is automatically called on destruction of the observers
    // (according to the `invalidate()` header documentation).
    private var observers = [NSKeyValueObservation]()
        
    private var tipObservationTask: Task<Void, Never>?

    // MARK: Gesture recognizer
    
    private let profilePictureTappedHandler: () -> Void
    private lazy var tappedProfilePictureGestureRecognizer = UITapGestureRecognizer(
        target: self,
        action: #selector(profilePictureTapped)
    )
    
    // MARK: Subviews

    private var isAvailabilityStatusExpanded = false

    /// Profile picture of contact or group
    private lazy var profilePictureView: ProfilePictureImageView = {
        let imageView = ProfilePictureImageView(iconConfiguration: .small)

        imageView.heightAnchor.constraint(equalToConstant: DetailsHeaderProfileView.configuration.profilePictureSize)
            .isActive = true
       
        // Configure full screen image gesture recognizer
        imageView.addGestureRecognizer(tappedProfilePictureGestureRecognizer)
        imageView.isUserInteractionEnabled = true
        imageView.backgroundColor = .clear
        imageView.isAccessibilityElement = false
        
        return imageView
    }()
    
    /// Name of contact or group
    private lazy var nameLabel: CopyLabel = {
        let label = CopyLabel()
        
        label.numberOfLines = 0
        label.textAlignment = .center
        
        label.setContentHuggingPriority(.defaultHigh, for: .vertical)
        
        // This needs to be set to a nonempty string (ideally the final string) otherwise
        // `systemLayoutSizeFitting(_:)` might return the wrong height. This is due to the fact that
        // the final text is only assigned when a configuration is applied.
        label.text = " "
                
        return label
    }()
    
    /// Verification level image of person
    private lazy var verificationLevelImageView: UIImageView = {
        let imageView = UIImageView()
        
        imageView.contentMode = .scaleAspectFit
        imageView.heightAnchor
            .constraint(equalToConstant: DetailsHeaderProfileView.configuration.verificationLevelHeight).isActive = true
                
        return imageView
    }()

    private lazy var availabilityStatusLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = DetailsHeaderProfileView.configuration.collapsedLineLimit
        label.textAlignment = .center
        label.adjustsFontForContentSizeCategory = true
        label.maximumContentSizeCategory = .extraExtraExtraLarge
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .label
        label.font = .preferredFont(forTextStyle: .body)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    private lazy var availabilityStatusExpandImage: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "chevron.down.circle")
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .body)
        imageView.maximumContentSizeCategory = .extraExtraExtraLarge
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .label
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.isHidden = true
        return imageView
    }()
    
    private lazy var availabilityStatusView: UIView = {
        let container = UIStackView(arrangedSubviews: [availabilityStatusLabel, availabilityStatusExpandImage])
        container.axis = .horizontal
        container.alignment = .center
        container.spacing = 8
        container.backgroundColor = .tertiarySystemFill
        container.translatesAutoresizingMaskIntoConstraints = false
        container.isLayoutMarginsRelativeArrangement = true
        container.layoutMargins = .init(top: 8, left: 24, bottom: 8, right: 24)
        container.layer.masksToBounds = true
        container.isHidden = true
        container.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(handleAvailabilityStatusTap))
        )
        return container
    }()

    // MARK: - Initialization
    
    init(with contentConfiguration: ContentConfiguration, profilePictureTapped: @escaping () -> Void) {
        self.contentConfiguration = contentConfiguration
        self.profilePictureTappedHandler = profilePictureTapped
        
        super.init(frame: .zero)
        
        configureView()
        updateContent()
        addObservers()
    }
    
    @available(*, unavailable, message: "Use init(for:delegate:with:)")
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        DDLogDebug("\(#function)")
        tipObservationTask?.cancel()
        tipObservationTask = nil
    }
    
    // MARK: - Configuration
    
    private func configureView() {
        // Configure name label font
        updateNameLabelFont()
        
        // Configure profile picture layout
        profilePictureView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            profilePictureView.topAnchor.constraint(equalTo: profilePictureView.topAnchor),
            profilePictureView.leadingAnchor.constraint(equalTo: profilePictureView.leadingAnchor),
            profilePictureView.bottomAnchor.constraint(equalTo: profilePictureView.bottomAnchor),
            profilePictureView.trailingAnchor.constraint(equalTo: profilePictureView.trailingAnchor),
        ])
        
        // Configure self (stack)
        axis = .vertical
        alignment = .center
        spacing = DetailsHeaderProfileView.configuration.defaultSpacing
        
        if DetailsHeaderProfileView.configuration.debug {
            backgroundColor = .systemRed
        }
        
        // Add default subviews
        addArrangedSubview(profilePictureView)

        addArrangedSubview(availabilityStatusView)
        availabilityStatusView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 1.0).isActive = true

        addArrangedSubview(nameLabel)

        // This needs to be set after the view is added as arranged subview
        // https://sarunw.com/posts/custom-uistackview-spacing/#caveat
        setCustomSpacing(
            DetailsHeaderProfileView.configuration.customSpacingAfterProfilePicture,
            after: isAvailabilityStatusVisible ? availabilityStatusView : profilePictureView
        )

        // Add verification level image to stack
        addArrangedSubview(verificationLevelImageView)
        
        isAccessibilityElement = true
        shouldGroupAccessibilityChildren = true
    }

    private var isAvailabilityStatusVisible: Bool {
        guard
            TargetManager.isWork,
            ThreemaEnvironment.workAvailabilityStatusEnabled,
            let availability = contentConfiguration.availabilityStatus,
            availability.category != .none
        else {
            return false
        }

        return true
    }

    private func addObservers() {
        // Dynamic type changed
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateNameLabelFont),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
    }
    
    // MARK: - Update functions
    
    private func updateContent() {
        profilePictureView.info = contentConfiguration.profilePictureInfo
        if let availabilityStatus = contentConfiguration.availabilityStatus, isAvailabilityStatusVisible {
            availabilityStatusLabel.text = availabilityStatus.text ?? availabilityStatus.category.localizedDescription
            availabilityStatusView.isHidden = false
        }
        else {
            availabilityStatusView.isHidden = true
        }
        
        if contentConfiguration.isSelfMember {
            nameLabel.attributedText = nil
            nameLabel.text = contentConfiguration.name
        }
        else {
            let attributeString = NSMutableAttributedString(string: contentConfiguration.name)
            attributeString.addAttribute(.strikethroughStyle, value: 2, range: NSMakeRange(0, attributeString.length))

            nameLabel.attributedText = attributeString
        }
        
        if let verificationLevelImage = contentConfiguration.verificationLevelImage {
            verificationLevelImageView.image = verificationLevelImage
            assert(
                contentConfiguration.verificationLevelAccessibilityLabel != nil,
                "A verification level accessibility description should be provided!"
            )
            verificationLevelImageView.accessibilityLabel = contentConfiguration.verificationLevelAccessibilityLabel
            verificationLevelImageView.isHidden = false
        }
        else {
            verificationLevelImageView.accessibilityLabel = ""
            verificationLevelImageView.isHidden = true
        }
    }

    /// Custom creation of semibold font for name label based on dynamic type
    @objc private func updateNameLabelFont() {
        nameLabel.font = DetailsHeaderProfileView.configuration.nameFont
    }
        
    // MARK: - Action
    
    @objc private func profilePictureTapped() {
        profilePictureTappedHandler()
    }

    @objc private func handleAvailabilityStatusTap() {
        guard !availabilityStatusExpandImage.isHidden else {
            return
        }
        isAvailabilityStatusExpanded.toggle()
        availabilityStatusLabel.numberOfLines = isAvailabilityStatusExpanded ? 0 : DetailsHeaderProfileView
            .configuration.collapsedLineLimit
        availabilityStatusExpandImage.image = UIImage(
            systemName: isAvailabilityStatusExpanded ? "chevron.up.circle" : "chevron.down.circle"
        )
    }
    
    func showThreemaTypeTip() {
        
        guard !ProcessInfoHelper.isRunningForScreenshots else {
            return
        }
        
        guard !UIAccessibility.isVoiceOverRunning else {
            return
        }
        
        guard !UserSettings.shared().workInfoShown, !profilePictureView.typeIconImageView.isHidden else {
            return
        }
        
        let typeTip = TipKitManager.ThreemaTypeTip()
        let threemaTypeTipView = TipUIView(typeTip, arrowEdge: .top)
        threemaTypeTipView.backgroundColor = .tertiarySystemBackground
        threemaTypeTipView.translatesAutoresizingMaskIntoConstraints = false
        
        tipObservationTask = tipObservationTask ?? Task(priority: .userInitiated) { @MainActor in
            for await shouldDisplay in typeTip.shouldDisplayUpdates {
                if shouldDisplay {
                    addSubview(threemaTypeTipView)
                    
                    NSLayoutConstraint.activate([
                        threemaTypeTipView.topAnchor
                            .constraint(equalTo: profilePictureView.typeIconImageView.bottomAnchor),
                        threemaTypeTipView.leadingAnchor
                            .constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.leadingAnchor),
                        threemaTypeTipView.trailingAnchor
                            .constraint(lessThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor),
                        threemaTypeTipView.centerXAnchor
                            .constraint(equalTo: profilePictureView.typeIconImageView.centerXAnchor),
                    ])
                }
                else {
                    threemaTypeTipView.removeFromSuperview()
                }
            }
        }
    }
    
    func showThreemaWorkAvailabilityStatusTip() {
        guard !ProcessInfoHelper.isRunningForScreenshots else {
            return
        }
        
        guard ThreemaEnvironment.workAvailabilityStatusEnabled else {
            return
        }
        
        guard !UIAccessibility.isVoiceOverRunning else {
            return
        }
        
        guard isAvailabilityStatusVisible else {
            return
        }
        
        let threemaWorkAvailabilityStatusTip = TipKitManager.ThreemaWorkAvailabilityStatusChatTip(forChat: true)
        let threemaWorkAvailabilityStatusTipView = TipUIView(threemaWorkAvailabilityStatusTip, arrowEdge: .top)
        threemaWorkAvailabilityStatusTipView.translatesAutoresizingMaskIntoConstraints = false
        
        tipObservationTask = tipObservationTask ?? Task(priority: .userInitiated) { @MainActor in
            for await shouldDisplay in threemaWorkAvailabilityStatusTip.shouldDisplayUpdates {
                if shouldDisplay {
                    addSubview(threemaWorkAvailabilityStatusTipView)
                    
                    NSLayoutConstraint.activate([
                        threemaWorkAvailabilityStatusTipView.topAnchor
                            .constraint(equalTo: availabilityStatusView.bottomAnchor),
                        threemaWorkAvailabilityStatusTipView.leadingAnchor
                            .constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.leadingAnchor),
                        threemaWorkAvailabilityStatusTipView.trailingAnchor
                            .constraint(lessThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor),
                        threemaWorkAvailabilityStatusTipView.centerXAnchor
                            .constraint(equalTo: availabilityStatusView.centerXAnchor),
                    ])
                }
                else {
                    threemaWorkAvailabilityStatusTipView.removeFromSuperview()
                }
            }
        }
    }
    
    // MARK: - Accessibility
    
    override var accessibilityLabel: String? {
        get {
            var text = "\(nameLabel.accessibilityLabel ?? "") ."
            
            if let status = contentConfiguration.availabilityStatus {
                text += status.accessibilityLabelWithText!
            }
            
            return text
        }
        set { }
    }
    
    override var accessibilityValue: String? {
        get {
            var accessibilityValueString = ""
            if !profilePictureView.typeIconImageView.isHidden {
                accessibilityValueString = ThreemaUtility.otherThreemaTypeAccessibilityLabel + ". "
            }
            
            return accessibilityValueString + (verificationLevelImageView.accessibilityLabel ?? "")
        }
        
        set { }
    }
}
