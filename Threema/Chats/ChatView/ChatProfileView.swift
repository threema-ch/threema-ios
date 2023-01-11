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
import ThreemaFramework
import UIKit

/// Chat profile view showed in the navigation bar of a chat
///
/// # The Problem
///
/// The profile view should appear at a fixed distance from the leading edge of the navigation bar (independent of the unread count next
/// to the back button) and go as far to the trailing edge as possible. (i.e. if there is no right bar button item it should span all the way to
/// the end offset by the margin.)
///
/// `UINavigationBar` allows a custom title view to be set through the front most `UINavigationItem`. In a normal setup (like
/// this) where the navigation bar is handled by a `UINavigationViewController` this can configured in the `navigationItem`
/// property of the front most view controller.
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
/// (`combinedLeadingAndTrailingOffset` in `ChatViewConfiguration.Profile`). This offset is a compromise to stay at
/// a fixed leading offset for all unread counts from none to 99. For more than 99 unread messages the profile is slightly pushed to the
/// trailing edge and might change its offset on any unread count change.
///
/// Limitation: This doesn't allow the view to span all the way to the trailing end. Otherwise the offset from the leading edge would change
/// on every update of the unread count and minimize the space for the back button in general.
///
/// # Other solutions considered
///
/// - **Custom right/left bar button item**: This would allow us to control the exact size including shown buttons on the trailing end.
///     Unfortunately, the default animation of bar button items is just a fade in if they aren't already part of the navigation bar during
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
final class ChatProfileView: UIStackView {
    
    typealias TapAction = () -> Void
    
    // MARK: - Public property
    
    /// Width of navigation bar adjusted to the safe area
    ///
    /// This is used to calculate the width of this view. The default value is for an iPhone X screen size.
    var safeAreaAdjustedNavigationBarWidth: CGFloat = 375 {
        didSet {
            guard safeAreaAdjustedNavigationBarWidth != oldValue else {
                return
            }

            widthConstraint.constant = (
                safeAreaAdjustedNavigationBarWidth - ChatViewConfiguration.Profile.combinedLeadingAndTrailingOffset
            )
            
            setNeedsLayout() // "Commit" update
        }
    }
    
    // MARK: - Private properties
    
    /// Enable colored backgrounds to help debugging
    private static let debug = false
    
    private let conversation: Conversation
    private let entityManager: EntityManager
    private lazy var group: Group? = GroupManager(
        entityManager: entityManager
    ).getGroup(conversation: conversation)

    // We need to hold on to the observers until the object is deallocated.
    // `invalidate()` is automatically called on destruction of them (according to the `invalidate()` header documentation).
    private var observers = [NSKeyValueObservation]()
    private lazy var memberObservers = [NSKeyValueObservation]()

    private lazy var widthConstraint = widthAnchor.constraint(
        equalToConstant: safeAreaAdjustedNavigationBarWidth -
            ChatViewConfiguration.Profile.combinedLeadingAndTrailingOffset
    )
    
    private let tapAction: TapAction
    
    private lazy var touchAnimator = UIViewPropertyAnimator.barButtonHighlightAnimator(for: self)
    
    // MARK: Views
    
    /// Avatar of contact or group
    private let avatarImageView: UIImageView = {
        let imageView = UIImageView(image: BundleUtil.imageNamed("Unknown"))
        
        imageView.contentMode = .scaleAspectFit
        
        // 1:1 aspect ratio
        imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor).isActive = true
        imageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        imageView.isAccessibilityElement = false
        imageView.accessibilityIgnoresInvertColors = true
        
        return imageView
    }()
    
    private lazy var otherThreemaTypeImageView = OtherThreemaTypeImageView()
    
    /// Name of contact or group
    private let nameLabel: UILabel = {
        let label = UILabel()
        
        label.font = ChatViewConfiguration.Profile.nameFont
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        if debug {
            label.backgroundColor = .systemGreen
        }
        
        label.isAccessibilityElement = false
        
        return label
    }()
    
    /// Verification level image of person
    private let verificationLevelImageView: UIImageView = {
        let imageView = UIImageView()
        
        imageView.contentMode = .scaleAspectFit
        NSLayoutConstraint.activate([
            imageView.heightAnchor.constraint(
                equalToConstant: ChatViewConfiguration.Profile.verificationLevelHeight
            ),
            // We set the aspect ratio to the size of the verification level image so we have not extra
            // leading or trailing space when the image gets resized.
            imageView.widthAnchor.constraint(
                equalTo: imageView.heightAnchor,
                multiplier: StyleKit.verificationSmallSize.width / StyleKit.verificationSmallSize.height
            ),
        ])
        imageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        if debug {
            imageView.backgroundColor = .systemYellow
        }
        
        imageView.isAccessibilityElement = false

        return imageView
    }()
    
    /// Label of group members list
    ///
    /// This might be truncated when displayed.
    ///
    /// - Note: This should never be hidden or set to an empty text. Otherwise the height of `verificationAndGroupMembersListStack` collapses.
    private let groupMembersListLabel: UILabel = {
        let label = UILabel()
        
        label.font = ChatViewConfiguration.Profile.groupMembersListFont
        
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        label.isAccessibilityElement = false

        return label
    }()
    
    /// Stack with name & members for group chats
    ///
    /// For single chats the verification level is shown on top and the group members list string with just a space.
    private lazy var nameAndGroupMembersListStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [
            nameLabel,
            groupMembersListLabel,
        ])
        
        stack.distribution = .fill
        
        if ChatProfileView.debug {
            stack.backgroundColor = .systemBlue
        }
        
        stack.isAccessibilityElement = false

        return stack
    }()
    
    /// Button overlaying the whole view to make it react to tapping
    private lazy var viewButton: UIButton = {
        let button = UIButton()
        button.isAccessibilityElement = false
        return button
    }()
    
    // MARK: - Initialization
    
    init(
        for conversation: Conversation,
        entityManager: EntityManager,
        tapAction: @escaping TapAction
    ) {
        self.conversation = conversation
        self.entityManager = entityManager
        self.tapAction = tapAction
        
        super.init(frame: .zero)
        
        self.isAccessibilityElement = true
        
        configureView()
        configureButton()
        configureContentObservers()
        updateColors()
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
        if conversation.contact?.showOtherThreemaTypeIcon ?? false {
            // Only add other Threema type icon if we actually want to show it
            avatarImageView.addSubview(otherThreemaTypeImageView)
            otherThreemaTypeImageView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                otherThreemaTypeImageView.widthAnchor.constraint(
                    equalTo: avatarImageView.widthAnchor,
                    multiplier: 0.35
                ),
                
                otherThreemaTypeImageView.leadingAnchor.constraint(equalTo: avatarImageView.leadingAnchor),
                otherThreemaTypeImageView.bottomAnchor.constraint(equalTo: avatarImageView.bottomAnchor),
            ])
        }
        
        // Add arranged subviews
        addArrangedSubview(avatarImageView)
        addArrangedSubview(nameAndGroupMembersListStack)
        
        // The verification level is vertically centered in the groupMembersListLabel which is never hidden
        // for a consistent appearance
        
        addSubview(verificationLevelImageView)
        verificationLevelImageView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            verificationLevelImageView.centerYAnchor.constraint(equalTo: groupMembersListLabel.centerYAnchor),
            verificationLevelImageView.leadingAnchor.constraint(equalTo: groupMembersListLabel.leadingAnchor),
        ])
        
        // Configure name and description verification stack
        updateNameAndVerificationDescriptionStack()
        
        // Configure self (stack)
        axis = .horizontal
        alignment = .center
        distribution = .fill
        spacing = ChatViewConfiguration.Profile.avatarAndInfoSpace
        
        // The leading and training insets are directly handled when `safeAreaAdjustedNavigationBarWidth` is set
        directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: ChatViewConfiguration.Profile.topAndBottomInset,
            leading: 0,
            bottom: ChatViewConfiguration.Profile.topAndBottomInset,
            trailing: 0
        )
        isLayoutMarginsRelativeArrangement = true
        
        widthConstraint.isActive = true
        
        if ChatProfileView.debug {
            backgroundColor = .systemOrange
        }
    }
    
    // Make to whole view tappable and react to it by imitating the button behavior of navigation bar buttons
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
        observe(conversation, \.displayName) { [weak self] in
            self?.nameLabel.text = self?.conversation.displayName
        }
    }
    
    private func configureSingleChatObservers() {
        guard let contact = conversation.contact else {
            return
        }
        
        // No need to call on creation as we already do the update when calling `updateColors`
        observe(contact, \.imageData, callOnCreation: false) { [weak self] in
            self?.updateAvatar()
        }
        
        // No need to call on creation as we already do the update when calling `updateColors`
        observe(contact, \.contactImage, callOnCreation: false) { [weak self] in
            self?.updateAvatar()
        }
        
        observe(contact, \.verificationLevel) { [weak self] in
            self?.verificationLevelImageView.image = self?.conversation.contact?.verificationLevelImageSmall()
        }
        
        // Needed to get appropriate height for verification and description stack (see `verificationAndGroupMembersListStack`)
        groupMembersListLabel.text = " "
    }
    
    private func configureGroupChatObservers() {
        guard let group = group else {
            return
        }
        
        // No need to call on creation as we already do the update when calling `updateColors`
        observe(group, \.photo, callOnCreation: false) { [weak self] in
            self?.updateAvatar()
        }
        
        // Observe changes of the member list and the name of each member
        observe(group, \.members) { [weak self] in
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
            weakSelf.addMemberObservers(for: weakSelf.group)
            
            // 4. Update label
            weakSelf.updateGroupMembersListLabel()
        }
        
        verificationLevelImageView.isHidden = true
    }
    
    private func addMemberObservers(for group: Group?) {
        guard let group = group else {
            return
        }

        for member in group.members {
            let memberNameObserver = member.observe(\.displayName) { [weak self] _, _ in
                DispatchQueue.main.async {
                    self?.updateGroupMembersListLabel()
                }
            }
            memberObservers.append(memberNameObserver)
        }
    }
    
    /// Helper to add observers
    ///
    /// All observers are stored in the `observers` property.
    ///
    /// - Parameters:
    ///   - object: Object to observe key path on
    ///   - keyPath: Key path in `object` to observe
    ///   - callOnCreation: Should the handler be called during observer creation?
    ///   - changeHandler: Handler called on each observed change (and initially if `callOnCreation` is `true`).
    ///                     Don't forget to capture `self` weakly! Dispatched on the main queue.
    private func observe<Object: NSObject, Value>(
        _ object: Object,
        _ keyPath: KeyPath<Object, Value>,
        callOnCreation: Bool = true,
        changeHandler: @escaping () -> Void
    ) {
        
        let options: NSKeyValueObservingOptions = callOnCreation ? .initial : []
        
        let observer = object.observe(keyPath, options: options) { _, _ in
            // Because `changeHandler` updates UI elements we need to ensure that it runs on the main queue
            DispatchQueue.main.async(execute: changeHandler)
        }
        
        observers.append(observer)
    }
    
    // MARK: - Update functions
    
    func updateColors() {
        updateAvatar()
        
        Colors.setTextColor(Colors.text, label: nameLabel)
        Colors.setTextColor(Colors.textLight, label: groupMembersListLabel)
    }
    
    @objc private func updateAvatar() {
        AvatarMaker.shared().avatar(
            for: conversation,
            size: ChatViewConfiguration.Profile.maxAvatarSize,
            masked: true
        ) { avatarImage, _ in
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
        let entityManager = EntityManager()
        entityManager.performBlockAndWait {
            let group = GroupManager(entityManager: entityManager).getGroup(conversation: self.conversation)
            // We always want at least one space in the label to keep it at a constant height
            self.groupMembersListLabel.text = group?.membersList ?? " "
        }
    }
    
    // MARK: - Actions
    
    @objc private func viewTapped() {
        tapAction()
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
        // Note: We cannot really adapt to any accessibility content size categories as they are not reported after
        // the view is added to a navigation bar `titleView`.
        if traitCollection.verticalSizeClass == .compact {
            // Compact configuration
            nameAndGroupMembersListStack.axis = .horizontal
            nameAndGroupMembersListStack.alignment = .firstBaseline
            nameAndGroupMembersListStack.spacing = ChatViewConfiguration.Profile.nameAndMembersListCompactSpacing
        }
        else {
            // Default configuration
            nameAndGroupMembersListStack.axis = .vertical
            nameAndGroupMembersListStack.alignment = .leading
            nameAndGroupMembersListStack.spacing = ChatViewConfiguration.Profile.nameAndMembersListRegularSpacing
        }
    }
    
    // MARK: - Accessibility
    
    override var accessibilityLabel: String? {
        get {
            conversation.displayName
        }
        set {
            // Do nothing
        }
    }
    
    override var accessibilityValue: String? {
        get {
            if !conversation.isGroup() {
                var otherThreemaAccessibilityLabel: String?
                if let contact = conversation.contact, contact.showOtherThreemaTypeIcon {
                    otherThreemaAccessibilityLabel = otherThreemaTypeImageView.accessibilityLabel
                }
                
                let accessibilityValue = [
                    conversation.contact?.verificationLevelAccessibilityLabel(),
                    otherThreemaAccessibilityLabel,
                ]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: ". ")
                
                return accessibilityValue
            }
            else {
                return nil
            }
        }
        set {
            // Do nothing
        }
    }
    
    override var accessibilityTraits: UIAccessibilityTraits {
        get {
            .button
        }
        set {
            // Do nothing
        }
    }
    
    override var accessibilityHint: String? {
        get {
            if conversation.isGroup() {
                return BundleUtil.localizedString(forKey: "accessibility_profile_button_hint_group")
            }
            else {
                return BundleUtil.localizedString(forKey: "accessibility_profile_button_hint_contact")
            }
        }
        set {
            // Do nothing
        }
    }
}
