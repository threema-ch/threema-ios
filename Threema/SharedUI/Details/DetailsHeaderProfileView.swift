//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2025 Threema GmbH
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
        /// Provides bool if user is member of the group
        let isSelfMember: Bool
        
        init(
            profilePictureInfo: ProfilePictureImageView.Info,
            name: String,
            verificationLevelImage: UIImage? = nil,
            verificationLevelAccessibilityLabel: String? = nil,
            isSelfMember: Bool = true
        ) {
            self.profilePictureInfo = profilePictureInfo
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
    
    /// Profile picture of contact or group
    private lazy var profilePictureView: ProfilePictureImageView = {
        let imageView = ProfilePictureImageView(typeIconConfiguration: .small)

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
        addArrangedSubview(nameLabel)
        
        // This needs to be set after the view is added as arranged subview
        // https://sarunw.com/posts/custom-uistackview-spacing/#caveat
        setCustomSpacing(
            DetailsHeaderProfileView.configuration.customSpacingAfterProfilePicture,
            after: profilePictureView
        )
        
        // Add verification level image to stack
        addArrangedSubview(verificationLevelImageView)
        
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
        profilePictureView.info = contentConfiguration.profilePictureInfo
       
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
        
        if #available(iOS 17, *) {
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
            var accessibilityValueString = ""
            if !profilePictureView.typeIconImageView.isHidden {
                accessibilityValueString = ThreemaUtility.otherThreemaTypeAccessibilityLabel + ". "
            }
            
            return accessibilityValueString + (verificationLevelImageView.accessibilityLabel ?? "")
        }
        
        set { }
    }
}
