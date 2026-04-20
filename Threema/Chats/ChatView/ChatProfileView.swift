import CocoaLumberjackSwift
import ThreemaFramework
import ThreemaMacros
import UIKit

/// Chat profile view showed in the navigation bar of a chat
///
/// # The Problem
///
/// The profile view should appear at a fixed distance from the leading edge of the navigation bar (independent of the
/// unread count next to the back button) and go as far to the trailing edge as possible. (i.e. if there is no right bar
/// button item it should span all the way to the end offset by the margin.)
///
/// `UINavigationBar` allows a custom title view to be set through the front most `UINavigationItem`. In a normal setup
/// (like this) where the navigation bar is handled by a `UINavigationViewController` this can be configured in the
/// `navigationItem` property of the front most view controller.
///
/// The problem with a navigation bar title view is that it is centered until it spans the complete width and there is
/// no direct public API to figure out the maximum width (or height for that matter) of the title view. Also no public
/// API exists to access the width of left and right (back) bar button items (to deduct them form the full navigation
/// bar width).
///
/// Constraints as the time of writing: Needs to support iOS 16 and later. (This didn't seem a limiting constraint in
/// our latest research)
///
/// # Solution chosen
///
/// ## iOS 17 and 18
///
/// We set the profile view to a fixed width, based on the width of the whole navigation bar minus an offset on both
/// ends (`combinedLeadingAndTrailingOffset` in `ChatViewConfiguration.Profile`). This offset is a compromise to stay at
/// a fixed leading offset for all unread counts from none to 99. For more than 99 unread messages the profile is
/// slightly pushed to the trailing edge and might change its offset on any unread count change.
///
/// Limitation: This doesn't allow the view to span all the way to the trailing end. Otherwise the offset from the
/// leading edge would change on every update of the unread count and minimize the space for the back button in general.
///
/// ## iOS 26 and later
///
/// Similar to before (iOS 17 & 18) we set the profile view to a fixed size, but because with Liquid Glass the back
/// button is bigger it varies if there is any unread message or none.  (`combinedLeadingAndTrailingOffset` &
/// `combinedLeadingAndTrailingOffsetWithUnreadMessages` in `ChatViewConfiguration.Profile`)
///
/// # Other solutions considered
///
/// - **Custom right/left bar button item**: This would allow us to control the exact size including shown buttons on
///   the trailing end. Unfortunately, the default animation of bar button items is just a fade in if they aren't
///   already part of the navigation bar during transition (compared to the title view). It is unclear how hard it would
///   be to replicate the default animation of the title view, but it might need adjustments on OS updates if the
///   default animation gets tweaked.
/// - **Use the full width available to the navigation bar title view**: This can be achieved by returning
///   `UIView.layoutFittingExpandedSize` from this view's `intrinsicContentSize`. The tradeoff here is that
///   on every unread count change the offset from the leading edge might change (especially if the number of digit
///   changes) unless we control the width of the back button area (arrow & unread count) which seems to be not
///   straight forward if possible at all. On iOS 26 this configuration also takes precedent over the back button width
/// and thus breaks the button if an unread count is shown.
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

            updateWidthConstraint()
        }
    }
    
    // MARK: - Private properties
    
    /// Enable colored backgrounds to help debugging
    private static let debug = false
    
    private let conversation: ConversationEntity
    private let entityManager: EntityManager
    private lazy var group: Group? = BusinessInjector.ui.groupManager
        .getGroup(conversation: conversation)
    
    // While we would be able to access the size class in the view's
    // trait collection, that value would not include the whole picture, only
    // the current context. In order to correctly assess it, we inject it,
    // letting the caller decide from where this information will be fetched.
    private let isRegularSizeClass: () -> Bool

    // We need to hold on to the observers until the object is deallocated.
    // `invalidate()` is automatically called on destruction of them (according to the `invalidate()` header
    // documentation).
    private var observers = [NSKeyValueObservation]()
    private lazy var memberObservers = [NSKeyValueObservation]()
    
    /// Current number of all unread messages in all chats
    ///
    /// - Note: This only relevant for width sizing in iOS 26 and later
    private var unreadCount = 0
    
    /// Task used for debouncing updates of width constraint
    private var updateWidthConstraintDebounceTask: Task<Void, Never>?
    
    // We skip the scaler here that is applied above on `safeAreaAdjustedNavigationBarWidth` updates
    private lazy var widthConstraint = widthAnchor.constraint(
        equalToConstant: safeAreaAdjustedNavigationBarWidth -
            ChatViewConfiguration.Profile.combinedLeadingAndTrailingOffset
    )
    
    private let tapAction: TapAction
    
    private lazy var touchAnimator = UIViewPropertyAnimator.barButtonHighlightAnimator(for: self)

    // MARK: Views
    
    /// Profile picture of contact or group
    private lazy var profilePictureView: ProfilePictureImageView = {
        let imageView = ProfilePictureImageView()
        imageView.addBackground()
        
        imageView.isAccessibilityElement = false
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.heightAnchor.constraint(equalToConstant: ChatViewConfiguration.Profile.profilePictureHeight),
        ])
        
        return imageView
    }()
        
    /// Name of contact or group
    private let nameLabel: UILabel = {
        let label = UILabel()
        
        label.font = ChatViewConfiguration.Profile.nameFont
        label.textColor = .label
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
    
    /// Label of members list
    ///
    /// This might be truncated when displayed.
    ///
    /// - Note: This should never be hidden or set to an empty text. Otherwise the height of
    ///         `nameAndMembersListStack` collapses.
    private let membersListLabel: UILabel = {
        let label = UILabel()
        
        label.font = ChatViewConfiguration.Profile.membersListFont
        if #available(iOS 26.0, *) {
            label.textColor = .label
        }
        else {
            label.textColor = .secondaryLabel
        }
        
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        label.isAccessibilityElement = false

        return label
    }()
    
    /// Stack with name & members for group chats
    ///
    /// For single chats the verification level is shown on top and the members list string with just a space.
    private lazy var nameAndMembersListStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [
            nameLabel,
            membersListLabel,
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
        for conversation: ConversationEntity,
        entityManager: EntityManager,
        initialUnreadCount: Int,
        isRegularSizeClass: @escaping () -> Bool,
        tapAction: @escaping TapAction,
    ) {
        self.conversation = conversation
        self.entityManager = entityManager
        self.isRegularSizeClass = isRegularSizeClass
        self.unreadCount = initialUnreadCount
        self.tapAction = tapAction
        
        super.init(frame: .zero)
        
        self.isAccessibilityElement = true
        
        configureView()
        configureButton()
        configureNotificationObservers()
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

    deinit {
        touchAnimator.stopAnimation(true)
    }

    // MARK: - Configuration
    
    private func configureView() {
        // Add arranged subviews
        addArrangedSubview(profilePictureView)
        addArrangedSubview(nameAndMembersListStack)
        
        // The verification level is vertically centered in the groupMembersListLabel which is never hidden
        // for a consistent appearance
        
        addSubview(verificationLevelImageView)
        verificationLevelImageView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            verificationLevelImageView.centerYAnchor.constraint(equalTo: membersListLabel.centerYAnchor),
            verificationLevelImageView.leadingAnchor.constraint(equalTo: membersListLabel.leadingAnchor),
        ])
        
        // Configure name and description verification stack
        updateNameAndVerificationDescriptionStack()
        
        // Configure self (stack)
        axis = .horizontal
        alignment = .center
        distribution = .fill
        spacing = ChatViewConfiguration.Profile.profilePictureAndInfoSpace
        
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
        
        // Do not pause animation for UI tests, it will break the test
        if !ProcessInfoHelper.isRunningForScreenshots {
            // Get callbacks to animate tapping
            viewButton.addTarget(self, action: #selector(touchDown), for: .touchDown)
            viewButton.addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        }
        viewButton.accessibilityIdentifier = "ChatProfileViewViewButton"
        
        addSubview(viewButton)
        
        viewButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            viewButton.topAnchor.constraint(equalTo: topAnchor),
            viewButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            viewButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            viewButton.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }
    
    private func configureNotificationObservers() {
        // We observe unread message count changes to adapt the width of the view when the back button (size) changes
        if #available(iOS 26.0, *) {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(unreadMessageCountChanged(_:)),
                name: NSNotification.Name(rawValue: kNotificationMessagesCountChanged),
                object: nil
            )
        }
    }
        
    private func configureContentObservers() {
        configureNameObserver()
        
        if conversation.isGroup {
            configureGroupChatObservers()
        }
        else if conversation.distributionList != nil {
            configureDistributionListObservers()
        }
        else {
            configureSingleChatObservers()
        }

        setupTraitRegistration()
    }
    
    private func configureNameObserver() {
        // Thanks to `keyPathsForValuesAffectingDisplayName` we should be subscribed to all relevant properties
        observe(conversation, \.displayName) { [weak self] in
            guard let self else {
                return
            }
            
            if conversation.isGroup {
                nameLabel.attributedText = group?.attributedDisplayName
            }
            else {
                nameLabel.attributedText = conversation.contact?.attributedDisplayName
            }
        }
    }
        
    private func configureSingleChatObservers() {
        guard let contact = conversation.contact else {
            return
        }
        
        let businessContact = Contact(contactEntity: contact)
        profilePictureView.info = .contact(businessContact)
        
        observe(contact, \.contactVerificationLevel) { [weak self] in
            self?.verificationLevelImageView.image = businessContact.verificationLevelImageSmall
        }
        
        observe(contact, \.contactState) { [weak self] in
            self?.nameLabel.attributedText = self?.conversation.contact?.attributedDisplayName
        }
        
        observe(UserSettings.shared(), \.blacklist) { [weak self] in
            self?.nameLabel.attributedText = self?.conversation.contact?.attributedDisplayName
        }
                
        // Needed to get appropriate height for verification and description stack (see
        // `nameAndMembersListStack`)
        membersListLabel.text = " "
    }
    
    private func configureGroupChatObservers() {
        guard let group else {
            return
        }
        
        profilePictureView.info = .group(group)
        
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
    
    private func configureDistributionListObservers() {
        guard let distributionList = conversation.distributionList else {
            return
        }
        
        let businessDistributionList = DistributionList(distributionListEntity: distributionList)
        profilePictureView.info = .distributionList(businessDistributionList)
        
        updateDistributionListRecipientsLabel()
        
        verificationLevelImageView.isHidden = true
    }
    
    private func addMemberObservers(for group: Group?) {
        guard let group else {
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
    ///                    Don't forget to capture `self` weakly! Dispatched on the main queue.
    private func observe<Object: NSObject>(
        _ object: Object,
        _ keyPath: KeyPath<Object, some Any>,
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
    
    @objc private func unreadMessageCountChanged(_ notification: Notification) {
        let newUnreadCount = notification.userInfo?[kKeyUnread] as? Int ?? 0
                        
        updateWidthConstraintWithDebounce(newUnreadCount: newUnreadCount)
    }
    
    // MARK: - Update functions
    
    private func updateWidthConstraintWithDebounce(newUnreadCount: Int) {
        updateWidthConstraintDebounceTask?.cancel()
        
        updateWidthConstraintDebounceTask = Task { @MainActor in
            
            unreadCount = newUnreadCount
            let conversationUnreadCount = conversation.unreadMessageCount.intValue
                    
            guard conversationUnreadCount == 0 || conversationUnreadCount != unreadCount else {
                DDLogNotice(
                    "Selected conversation has no unread message or unread count only comes from the selected conversation"
                )
                return
            }
            
            // Wait a bit such that the there is no fast showing and hiding of the unread count if it switches back
            // and forth between 0 and another number (e.g. when the chat opens)
            // This needs to be in sync with the sleep in `ConversationListViewController.setBackButton(unread:)`
            guard await (try? Task.sleep(for: .milliseconds(500))) != nil else {
                // no-op as we just not run it when canceled
                return
            }
            
            updateWidthConstraint()
        }
    }
    
    private func updateWidthConstraint() {
        let scaler: CGFloat =
            if #available(iOS 26.0, *) {
                1
            }
            else {
                // Because the sizing in the navigation bar changes slightly for the system components (i.e. back button
                // &
                // label) we need to also adjust the width such that unread counts < 100 are not cut off. As the sizing
                // changes are small we take the log of the scaler.
                log10(UIFontMetrics.default.scaledValue(for: 10))
            }
        
        let constant =
            if isRegularSizeClass() {
                ChatViewConfiguration.Profile.combinedLeadingAndTrailingOffsetRegularSizeClass
            }
            else if unreadCount > 0 {
                ChatViewConfiguration.Profile.combinedLeadingAndTrailingOffsetWithUnreadMessages
            }
            else {
                ChatViewConfiguration.Profile.combinedLeadingAndTrailingOffset
            }
        
        let newConstant = safeAreaAdjustedNavigationBarWidth - (scaler * constant)
        
        guard newConstant != widthConstraint.constant else {
            DDLogDebug("No need to update width constraint constant")
            return
        }
            
        widthConstraint.constant = newConstant
        
        setNeedsLayout() // "Commit" update
    }
        
    private func updateGroupMembersListLabel() {
        let businessInjector = BusinessInjector.ui
        businessInjector.entityManager.performAndWait {
            let group = businessInjector.groupManager.getGroup(conversation: self.conversation)
            // We always want at least one space in the label to keep it at a constant height
            self.membersListLabel.text = group?.membersList ?? " "
        }
    }
    
    private func updateDistributionListRecipientsLabel() {
        // We always want at least one space in the label to keep it at a constant height
        let distributionList = BusinessInjector.ui.distributionListManager
            .distributionList(for: conversation)
        
        membersListLabel.text = distributionList?.recipientsSummary ?? " "
    }

    private func setupTraitRegistration() {
        let traits: [UITrait] = [UITraitPreferredContentSizeCategory.self]
        registerForTraitChanges(traits) { [weak self] (_: Self, previous) in
            guard let self else {
                return
            }
            if previous.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
                updateNameAndVerificationDescriptionStack()
            }
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

    /// Set name and verification description stack based on size class
    ///
    /// This is due to the fact that the navigation bar height is smaller with a compact vertical size class (e.g.
    /// landscape on most iPhones).
    private func updateNameAndVerificationDescriptionStack() {
        // Note: We cannot really adapt to any accessibility content size categories as they are not reported after
        // the view is added to a navigation bar `titleView`.
        if traitCollection.verticalSizeClass == .compact {
            // Compact configuration
            nameAndMembersListStack.axis = .horizontal
            nameAndMembersListStack.alignment = .firstBaseline
            nameAndMembersListStack.spacing = ChatViewConfiguration.Profile.nameAndMembersListCompactSpacing
        }
        else {
            // Default configuration
            nameAndMembersListStack.axis = .vertical
            nameAndMembersListStack.alignment = .leading
            nameAndMembersListStack.spacing = ChatViewConfiguration.Profile.nameAndMembersListRegularSpacing
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
            if !conversation.isGroup {
                guard let contact = conversation.contact else {
                    return nil
                }
                
                let businessContact = Contact(contactEntity: contact)
                let label = [businessContact.verificationLevelAccessibilityLabel]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: ". ")
                
                return label
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
            if conversation.isGroup {
                #localize("accessibility_profile_button_hint_group")
            }
            else {
                #localize("accessibility_profile_button_hint_contact")
            }
        }
        set {
            // Do nothing
        }
    }
}
