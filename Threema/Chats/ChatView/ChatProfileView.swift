//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2022 Threema GmbH
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

protocol ChatProfileViewDelegate: AnyObject {
    func chatProfileViewTapped(_ chatProfileView: ChatProfileView)
}

extension ChatProfileView {
    /// Configuration parameters for `ChatProfileView`
    ///
    /// This is encapsulated to prevent name space pollution and to show relation.
    struct Configuration {
        /// Show debug background colors
        let debug = false
        
        /// Combined leading and trailing offset from the navigation width
        let combinedLeadingAndTrailingOffset: CGFloat = 2 * 60
        
        /// All content is offset by these margins
        let margins = NSDirectionalEdgeInsets(
            top: 4,
            leading: 0,
            bottom: 4,
            trailing: 0
        )
        
        let maxAvatarSize: CGFloat = 36
        let avatarTrailingMargin: CGFloat = 8
        let verificationLevelHeight: CGFloat = 8
        let nameVerificationAndDescriptionRegularSpacing: CGFloat = 0
        let nameVerificationAndDescriptionCompactSpacing: CGFloat = 8
    }
}

/// Chat Profile View showed in the navigation bar of a chat
///
/// # The Problem
///
/// The profile view should appear at a fixed distance from the leading edge of the navigation bar (independent of the unread count next
/// to the back button) and go as far to the trailing edge as possible. (i.e. if there is no right bar button item it should span all the way to
/// the end offset by the margin.)
///
/// `UINavigationBar` allows a custom title view to be set through the front most `UINavigationItem`. In a normal setup (like
/// this) where the navigation bar is handled by a `UINavigationViewController` this can configured in the `navigationItem`
/// property of the front most navigation controller.
///
/// The problem with a navigation bar title view is that it is centered until ist spans the complete width and there is no direct public API to
/// figure out the maximum width (or height for that matter) of the title view. Also no public API exists to access the width of left and
/// right (back) bar button items (to deduct them form the full navigation bar width).
///
/// Constraints as the time of writing: Needs to support iOS 12.
///
/// # Solution chosen
///
/// We set the profile view to a fixed width, based on the width of the whole navigation bar minus an offset on both ends
/// (`combinedLeadingAndTrailingOffset` in `ChatProfileView.Configuration`). This offset is a compromise to stay at
/// a fixed leading offset for all unread counts from none to 99. For more than 99 unread messages the profile is slightly pushed to the
/// trailing edge and might change its offset on any unread count change.
///
/// Limitation: This doesn't allow the view to span all the way to the trailing end. Otherwise the offset from the leading edge would change
/// on every update of the unread count and minimize the space for the back button in general.
///
/// # Other solutions considered
///
/// - **Custom right/left bar button item**: This would allow us to control the exact size including shown buttons on the trailing end.
///     Unfortunately, the default animation of bar button items is just a fade in and they aren't already part of the navigation bar during
///     transition (compared to the title view). It is unclear how hard it would be to replicate the default animation of the title view, but it
///     might need adjustments on OS updates if the default animation gets tweaked.
/// - **Use the full width available to the navigation bar title view**: This can be achieved by returning
///     `UIView.layoutFittingExpandedSize` from this view's `intrinsicContentSize`. The tradeoff here is that
///     on every unread count change the offset from the leading edge might change (especially if the number of digit changes) unless
///     we control the width of the back button area (arrow & unread count) which seems to be not straight forward if possible at all.
///
/// # Solutions that might be considered in the future
///
/// - With the addition of `UINavigationBarAppearance` in iOS 13 there is more possibility to control the navigation bar appearance
///     this might allow us to control the size of the back button area or at least set the back button text (unread count) to monospaced digits.
/// - Workaround to get the right and left bar button items: https://stackoverflow.com/a/46965131
///
final class ChatProfileView: UIStackView {
    
    // MARK: - Public property
    
    /// Width of navigation bar adjusted to the safe area
    ///
    /// This is used to calculate the width of this view. The default value is for an iPhone X screen size.
    var safeAreaAdjustedNavigationBarWidth: CGFloat = 375 {
        didSet {
            guard safeAreaAdjustedNavigationBarWidth != oldValue,
                  let widthConstraint = widthConstraint else {
                return
            }

            widthConstraint
                .constant = (safeAreaAdjustedNavigationBarWidth - configuration.combinedLeadingAndTrailingOffset)
            setNeedsLayout() // "Commit" update
        }
    }
    
    /// Delegate for this instance
    weak var delegate: ChatProfileViewDelegate?
    
    // MARK: - Private properties
    
    private let conversation: Conversation
    private let configuration: ChatProfileView.Configuration

    // We need to hold on to the observers until the object is deallocated.
    // `invalidate()` is automatically called on destruction of them (according to the `invalidate()` header documentation).
    private var observers = [NSKeyValueObservation]()
    private lazy var memberObservers = [NSKeyValueObservation]()

    private var widthConstraint: NSLayoutConstraint?
    
    private lazy var touchAnimator = UIViewPropertyAnimator.barButtonHighlightAnimator(for: self)
    
    // MARK: Subviews
    
    /// Avatar of contact or group
    private let avatarImageView = UIImageView(image: BundleUtil.imageNamed("Unknown"))
    
    /// Name of contact or group
    private let nameLabel = UILabel()
    
    /// Verification level image of person
    private let verificationLevelImageView = UIImageView()
    
    /// Label of group members list
    ///
    /// This might be truncated when displayed.
    ///
    /// - Note: This should never be hidden or set to an empty text. Otherwise the height of `verificationAndGroupMembersListStack` collapses.
    private let groupMembersListLabel = UILabel()
    
    /// Stack with verification level image and group members list label
    ///
    /// This is used to assure a consistent height of the line below the name label, based on the text size of group members list label.
    private let verificationAndGroupMembersListStack = UIStackView()
    
    /// Stack with name & related info (i.e. verification level for single chat and members for group chats)
    private let nameAndVerificationGroupMembersListStack = UIStackView()
    
    /// Button overlaying the whole view to make it react to tapping
    ///
    /// Maybe there is a more elegant solution to that
    private let viewButton = UIButton()
    
    // MARK: - Initialization
    
    init(for conversation: Conversation, with configuration: ChatProfileView.Configuration = Configuration()) {
        self.conversation = conversation
        self.configuration = configuration
        
        super.init(frame: .zero)
        
        configureView()
        configureButton()
        configureContentObservers()
    }
    
    @available(*, unavailable, message: "Use init(for:)")
    override init(frame: CGRect) {
        fatalError("Use init(for: Conversation)")
    }
    
    @available(*, unavailable, message: "Use init(for:)")
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Destruction
    
    deinit {
        touchAnimator.stopAnimation(true)
    }
    
    // MARK: - Configuration
    
    private func configureView() {
        // Configure avatar view
        avatarImageView.contentMode = .scaleAspectFit
        avatarImageView.accessibilityIgnoresInvertColors = true
        avatarImageView.widthAnchor.constraint(equalTo: avatarImageView.heightAnchor).isActive = true
        avatarImageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        // Configure name label
        nameLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        if configuration.debug {
            nameLabel.backgroundColor = .systemGreen
        }
        
        // Configure verification level image
        verificationLevelImageView.contentMode = .scaleAspectFit
        verificationLevelImageView.heightAnchor.constraint(equalToConstant: configuration.verificationLevelHeight)
            .isActive = true
        verificationLevelImageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        if configuration.debug {
            verificationLevelImageView.backgroundColor = .systemYellow
        }
        
        // Configure group member list label
        groupMembersListLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        groupMembersListLabel.textColor = Colors.textLight
        groupMembersListLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        // Configure verification and description stack
        verificationAndGroupMembersListStack.axis = .horizontal
        verificationAndGroupMembersListStack.alignment = .center
        verificationAndGroupMembersListStack.distribution = .fill
        // This spacing should never be visible to a user, because either verificationLevelImageView
        // is hidden or groupMembersListLabel contains a single space
        verificationAndGroupMembersListStack.spacing = 8
        
        if configuration.debug {
            verificationAndGroupMembersListStack.backgroundColor = .systemRed
        }
        
        verificationAndGroupMembersListStack.addArrangedSubview(verificationLevelImageView)
        verificationAndGroupMembersListStack.addArrangedSubview(groupMembersListLabel)
                
        // Configure name and description verification stack
        updateNameAndVerificationDescriptionStack()
        nameAndVerificationGroupMembersListStack.distribution = .fill
        
        if configuration.debug {
            nameAndVerificationGroupMembersListStack.backgroundColor = .systemBlue
        }
        
        nameAndVerificationGroupMembersListStack.addArrangedSubview(nameLabel)
        nameAndVerificationGroupMembersListStack.addArrangedSubview(verificationAndGroupMembersListStack)
        
        // Configure self (stack)
        axis = .horizontal
        alignment = .center
        distribution = .fill
        spacing = configuration.avatarTrailingMargin
         
        directionalLayoutMargins = configuration.margins
        isLayoutMarginsRelativeArrangement = true

        widthConstraint = widthAnchor
            .constraint(
                equalToConstant: safeAreaAdjustedNavigationBarWidth - configuration
                    .combinedLeadingAndTrailingOffset
            )
        widthConstraint?.isActive = true
        
        if configuration.debug {
            backgroundColor = .systemOrange
        }
        
        // Add arranged subviews
        addArrangedSubview(avatarImageView)
        addArrangedSubview(nameAndVerificationGroupMembersListStack)
    }
    
    /// Make to whole view tappable and react to it by imitating the button behavior of navigation bar buttons
    private func configureButton() {
        // Make the view tappable
        viewButton.addTarget(self, action: #selector(viewTapped), for: .touchUpInside)
        
        // Get callbacks to animate tapping
        viewButton.addTarget(self, action: #selector(touchDown), for: .touchDown)
        viewButton.addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        addSubview(viewButton)
        
        viewButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            viewButton.topAnchor.constraint(equalTo: topAnchor),
            viewButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            viewButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            viewButton.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }
        
    private func configureContentObservers() {
        configureNameObserver()
        
        // Update avatar if setting of which avatar to show changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateAvatar),
            name: Notification.Name(kNotificationShowProfilePictureChanged),
            object: nil
        )
        
        if !conversation.isGroup() {
            configureSingleChatObservers()
        }
        else {
            configureGroupChatObservers()
        }
    }
    
    private func configureNameObserver() {
        // Thanks to `keyPathsForValuesAffectingDisplayName` we should be subscribed to all relevant properties
        observeConversation(\.displayName) { [weak self] in
            self?.nameLabel.text = self?.conversation.displayName
            self?.updateAccessibilityLabel()
        }
    }
    
    private func configureSingleChatObservers() {
        
        guard let _ = conversation.contact else {
            return
        }
        
        observeConversation(\.contact!.imageData) { [weak self] in
            self?.updateAvatar()
        }
        
        // No need to call on creation as we did that above
        observeConversation(\.contact!.contactImage, callOnCreation: false) { [weak self] in
            self?.updateAvatar()
        }
        
        observeConversation(\.contact!.verificationLevel) { [weak self] in
            guard let verificationLevelImage = self?.conversation.contact?.verificationLevelImageSmall() else {
                return
            }
            
            self?.verificationLevelImageView.image = verificationLevelImage
            self?.updateAccessibilityLabel()
        }
        
        // Needed to get appropriate height for verification and description stack (see `verificationAndGroupMembersListStack`)
        groupMembersListLabel.text = " "
    }
    
    private func configureGroupChatObservers() {
        observeConversation(\.groupImage) { [weak self] in
            self?.updateAvatar()
        }
        
        // Observe changes of the member list and the name of each member
        observeConversation(\.members) { [weak self] in
            guard let weakSelf = self else {
                return
            }
            
            // 1. Unsubscribe from all member observers
            for observer in weakSelf.memberObservers {
                observer.invalidate()
            }
            
            // 2. Remove all references
            weakSelf.memberObservers.removeAll()
            
            // 3. Observe name changes of all current members (we need to update the name list on a change)
            weakSelf.addMemberObservers(for: weakSelf.conversation)
            
            // 4. Update label
            weakSelf.updateGroupMembersListLabel()
        }
        
        verificationLevelImageView.isHidden = true
    }
    
    private func addMemberObservers(for conversation: Conversation) {
        
        for member in conversation.members {
            let memberNameObserver = member.observe(\.displayName) { [weak self] _, _ in
                DispatchQueue.main.async {
                    self?.updateGroupMembersListLabel()
                }
            }
            memberObservers.append(memberNameObserver)
        }
    }
    
    /// Helper to add observers to the `conversation` property
    ///
    /// All observers are store in the `observers` property.
    ///
    /// - Parameters:
    ///   - keyPath: Key path in `Conversation` to observe
    ///   - callOnCreation: Should the handler be called during observer creation?
    ///   - changeHandler: Handler called on each observed change (and initially if `callOnCreation` is `true`).
    ///                     Don't forget to capture `self` weakly! Dispatched on the main queue.
    private func observeConversation<Value>(
        _ keyPath: KeyPath<Conversation, Value>,
        callOnCreation: Bool = true,
        changeHandler: @escaping () -> Void
    ) {
        
        let options: NSKeyValueObservingOptions = callOnCreation ? .initial : []
        
        let observer = conversation.observe(keyPath, options: options) { _, _ in
            // Because `changeHandler` updates UI elements we need to ensure that it runs on the main queue
            DispatchQueue.main.async(execute: changeHandler)
        }
        
        observers.append(observer)
    }
    
    // MARK: - Update functions
    
    @objc private func updateAvatar() {
        AvatarMaker.shared()
            .avatar(for: conversation, size: configuration.maxAvatarSize, masked: true) { avatarImage, _ in
                guard let avatarImage = avatarImage else {
                    // We have a default avatar. No worries.
                    return
                }
            
                DispatchQueue.main.async {
                    self.avatarImageView.image = avatarImage
                }
            }
    }
    
    private func updateGroupMembersListLabel() {
        // TODO: (IOS-2404) Do a cleaner implementation
        let group = GroupManager(entityManager: EntityManager()).getGroup(conversation: conversation)
        
        groupMembersListLabel.text = group?.membersList ?? ""
    }
    
    private func updateAccessibilityLabel() {
        if !conversation.isGroup() {
            accessibilityLabel =
                "\(conversation.displayName ?? ""). \(conversation.contact?.verificationLevelAccessibilityLabel() ?? "")"
        }
        else {
            accessibilityLabel = conversation.displayName
        }
    }
    
    // MARK: - Actions
    
    @objc private func viewTapped() {
        delegate?.chatProfileViewTapped(self)
    }
    
    @objc private func touchDown() {
        touchAnimator.pauseAnimation()
        touchAnimator.isReversed = false
        touchAnimator.startAnimation()
    }
    
    @objc private func touchUp() {
        touchAnimator.pauseAnimation()
        touchAnimator.isReversed = true
        touchAnimator.startAnimation()
    }
    
    // MARK: - Environment changes
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.verticalSizeClass != previousTraitCollection?.verticalSizeClass {
            updateNameAndVerificationDescriptionStack()
        }
    }
    
    /// Set name and verification description stack based on size class
    ///
    /// This is due to the fact that the navigation bar height is smaller with a compact vertical size class (e.g. landscape on most iPhones).
    private func updateNameAndVerificationDescriptionStack() {
        if traitCollection.verticalSizeClass == .compact {
            // Compact configuration
            nameAndVerificationGroupMembersListStack.axis = .horizontal
            nameAndVerificationGroupMembersListStack.alignment = .firstBaseline
            nameAndVerificationGroupMembersListStack.spacing = configuration
                .nameVerificationAndDescriptionCompactSpacing
        }
        else {
            // Default configuration
            nameAndVerificationGroupMembersListStack.axis = .vertical
            nameAndVerificationGroupMembersListStack.alignment = .leading
            nameAndVerificationGroupMembersListStack.spacing = configuration
                .nameVerificationAndDescriptionRegularSpacing
        }
    }
    
    // MARK: - Accessibility

    override var accessibilityLabel: String? {
        didSet {
            viewButton.accessibilityLabel = accessibilityLabel
        }
    }
}
