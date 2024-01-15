//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2024 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import CocoaLumberjackSwift
import UIKit

// MARK: - DetailsHeaderProfileView.Configuration

extension DetailsHeaderProfileView {
    struct Configuration: DetailsConfiguration {
        /// Show debug background colors
        let debug = false
        
        let defaultSpacing: CGFloat = 8
        
        let customSpacingAfterAvatar: CGFloat = 10

        let verificationLevelHeight: CGFloat = 12
                
        let threemaTypeInfoShowcasePrimaryTextSize: CGFloat = 24
        let threemaTypeInfoShowcaseSecondaryTextSize: CGFloat = 20
        
        let defaultAvatarImage = BundleUtil.imageNamed("Unknown")
    }
}

final class DetailsHeaderProfileView: UIStackView {
    
    /// Entity agnostic header configuration
    struct ContentConfiguration {
        /// Provides current avatar that should be shown
        /// This happens in the provided completion closure to allow background loading
        let avatarImageProvider: (@escaping (UIImage?) -> Void) -> Void
        /// Show work or other icon next to avatar?
        let hideThreemaTypeIcon: Bool
        /// Name shown
        let name: String
        /// Provide image for verification level if any
        let verificationLevelImage: UIImage?
        /// Provide accessibility description for verification level if any.
        /// This should be set if `verificationLevelImage` is not `nil`.
        let verificationLevelAccessibilityLabel: String?
        /// Provides bool if user is member of the group
        let isSelfMember: Bool
        
        init(
            avatarImageProvider: @escaping (@escaping (UIImage?) -> Void) -> Void,
            hideThreemaTypeIcon: Bool = true,
            name: String,
            verificationLevelImage: UIImage? = nil,
            verificationLevelAccessibilityLabel: String? = nil,
            isSelfMember: Bool = true
        ) {
            self.avatarImageProvider = avatarImageProvider
            self.hideThreemaTypeIcon = hideThreemaTypeIcon
            self.name = name
            self.verificationLevelImage = verificationLevelImage
            self.verificationLevelAccessibilityLabel = verificationLevelAccessibilityLabel
            self.isSelfMember = isSelfMember
        }
    }
    
    var contentConfiguration: ContentConfiguration {
        didSet {
            updateContent()
        }
    }
    
    static var avatarImageSize: CGFloat {
        configuration.avatarSize
    }

    // MARK: - Private properties
    
    private static let configuration = Configuration()

    // We need to hold on to the observers until this object is deallocated.
    // `invalidate()` is automatically called on destruction of the observers
    // (according to the `invalidate()` header documentation).
    private var observers = [NSKeyValueObservation]()
    
    private let isWorkApp = LicenseStore.requiresLicenseKey()
    
    // MARK: Gesture recognizer
    
    private let avatarImageTappedHandler: () -> Void
    private lazy var tappedAvatarImageGestureRecognizer = UITapGestureRecognizer(
        target: self,
        action: #selector(avatarImageTapped)
    )
    
    // MARK: Subviews

    private let avatarContainer: UIView = {
        let view = UIView()
        
        view.backgroundColor = .clear
        
        view.isAccessibilityElement = false
        
        return view
    }()
    
    /// Avatar of contact or group
    private lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView(image: DetailsHeaderProfileView.configuration.defaultAvatarImage)
        
        imageView.contentMode = .scaleAspectFit // oder fill wie bisher?
        // Aspect ratio: 1:1
        imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor).isActive = true
        // Fixed avatar size
        imageView.heightAnchor.constraint(equalToConstant: DetailsHeaderProfileView.configuration.avatarSize)
            .isActive = true
        
        // Configure full screen image gesture recognizer
        imageView.addGestureRecognizer(tappedAvatarImageGestureRecognizer)
        imageView.isUserInteractionEnabled = true
        
        imageView.accessibilityIgnoresInvertColors = true
        
        return imageView
    }()
    
    /// Threema work or private icon next to avatar
    private lazy var threemaTypeIcon: UIButton = {
        let button = UIButton()
        
        button.setImage(ThreemaUtility.otherThreemaTypeIcon, for: .normal)
        button.isHidden = true
        // Aspect ratio: 1:1
        button.widthAnchor.constraint(equalTo: button.heightAnchor).isActive = true
        
        button.addTarget(self, action: #selector(showThreemaTypeInfo(autoDismiss:)), for: .touchUpInside)
        
        button.accessibilityLabel = ThreemaUtility.otherThreemaTypeAccessibilityLabel
        button.accessibilityIgnoresInvertColors = true
        
        return button
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
    
    // MARK: Modal subview
    
    private lazy var threemaTypeInfoShowcase: MaterialShowcase = {
        let materialShowcase = MaterialShowcase()
        
        materialShowcase.setTargetView(button: threemaTypeIcon)
        
        if !isWorkApp {
            materialShowcase.primaryText = BundleUtil.localizedString(forKey: "contact_threema_work_title")
            materialShowcase.secondaryText = BundleUtil.localizedString(forKey: "contact_threema_work_info")
            materialShowcase.backgroundPromptColor = Colors.blue
        }
        else {
            materialShowcase.primaryText = BundleUtil.localizedString(forKey: "contact_threema_title")
            materialShowcase.secondaryText = BundleUtil.localizedString(forKey: "contact_threema_info")
            materialShowcase.backgroundPromptColor = Colors.green
        }
        
        materialShowcase.backgroundPromptColorAlpha = 0.93
        materialShowcase.primaryTextSize = DetailsHeaderProfileView.configuration.threemaTypeInfoShowcasePrimaryTextSize
        materialShowcase.secondaryTextSize = DetailsHeaderProfileView.configuration
            .threemaTypeInfoShowcaseSecondaryTextSize
        materialShowcase.primaryTextColor = Colors.textMaterialShowcase
        materialShowcase.secondaryTextColor = Colors.textMaterialShowcase
        
        materialShowcase.targetHolderRadius = threemaTypeIcon.bounds.width
        
        return materialShowcase
    }()

    // MARK: - Initialization
    
    init(with contentConfiguration: ContentConfiguration, avatarImageTapped: @escaping () -> Void) {
        self.contentConfiguration = contentConfiguration
        self.avatarImageTappedHandler = avatarImageTapped
        
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
    }
    
    // MARK: - Configuration
    
    private func configureView() {
        // Configure name label font
        updateNameLabelFont()
        
        // Configure avatar container layout
        avatarContainer.addSubview(avatarImageView)
        
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            avatarImageView.topAnchor.constraint(equalTo: avatarContainer.topAnchor),
            avatarImageView.leadingAnchor.constraint(equalTo: avatarContainer.leadingAnchor),
            avatarImageView.bottomAnchor.constraint(equalTo: avatarContainer.bottomAnchor),
            avatarImageView.trailingAnchor.constraint(equalTo: avatarContainer.trailingAnchor),
        ])
        
        // Configure self (stack)
        axis = .vertical
        alignment = .center
        spacing = DetailsHeaderProfileView.configuration.defaultSpacing
        
        if DetailsHeaderProfileView.configuration.debug {
            backgroundColor = .systemRed
        }
        
        // Add default subviews
        addArrangedSubview(avatarContainer)
        addArrangedSubview(nameLabel)
        
        // This needs to be set after the view is added as arranged subview
        // https://sarunw.com/posts/custom-uistackview-spacing/#caveat
        setCustomSpacing(DetailsHeaderProfileView.configuration.customSpacingAfterAvatar, after: avatarImageView)
        
        // Add verification level image to stack
        addArrangedSubview(verificationLevelImageView)
        
        // Configure Threema type icon layout (this might not be shown)
        avatarContainer.addSubview(threemaTypeIcon)
        
        threemaTypeIcon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            // 1/4 of the avatar image size
            threemaTypeIcon.widthAnchor.constraint(equalTo: avatarImageView.widthAnchor, multiplier: 0.25),
            
            threemaTypeIcon.leadingAnchor.constraint(equalTo: avatarImageView.leadingAnchor),
            threemaTypeIcon.bottomAnchor.constraint(equalTo: avatarImageView.bottomAnchor),
        ])
        
        isAccessibilityElement = true
        shouldGroupAccessibilityChildren = true
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
        contentConfiguration.avatarImageProvider { avatarImage in
            if let avatarImage {
                self.avatarImageView.image = avatarImage
            }
            else {
                self.avatarImageView.image = DetailsHeaderProfileView.configuration.defaultAvatarImage
            }
        }
        
        threemaTypeIcon.isHidden = contentConfiguration.hideThreemaTypeIcon
        
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
    
    @objc private func avatarImageTapped() {
        avatarImageTappedHandler()
    }
    
    /// Show Threema type info if it was never shown before
    func autoShowThreemaTypeInfo() {
        
        guard !ProcessInfoHelper.isRunningForScreenshots else {
            return
        }
        
        guard let infoShown = UserSettings.shared()?.workInfoShown,
              !infoShown,
              !contentConfiguration.hideThreemaTypeIcon else {
            return
        }
        
        // Short delay so it appears in the right place on iPad
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.showThreemaTypeInfo(autoDismiss: true)
        }
    }
    
    /// Show threema type info if icon is shown
    ///
    /// - Parameter autoDismiss: Automatically dismiss overlay after some seconds
    @objc func showThreemaTypeInfo(autoDismiss: Bool = false) {
        
        guard !ProcessInfoHelper.isRunningForScreenshots else {
            return
        }
        
        guard !threemaTypeIcon.isHidden else {
            return
        }
        
        threemaTypeIcon.isHighlighted = false
        threemaTypeIcon.isSelected = false
        
        threemaTypeInfoShowcase.show(hasShadow: false, hasSkipButton: false) {
            UserSettings.shared()?.workInfoShown = true
        }
        
        if autoDismiss {
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                self.threemaTypeInfoShowcase.completeShowcase()
            }
        }
    }
    
    // MARK: - Accessibility
    
    override var accessibilityLabel: String? {
        get {
            nameLabel.accessibilityLabel
        }
        set { }
    }
    
    override var accessibilityValue: String? {
        get {
            var threemaTypeIconAccessibilityLabel = ""
            if !threemaTypeIcon.isHidden {
                threemaTypeIconAccessibilityLabel = ThreemaUtility.otherThreemaTypeAccessibilityLabel
            }
            
            return [
                threemaTypeIconAccessibilityLabel,
                verificationLevelImageView.accessibilityLabel,
            ]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ". ")
        }
        
        set { }
    }
}
