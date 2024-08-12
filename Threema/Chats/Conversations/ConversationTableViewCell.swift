//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
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
import Combine
import GroupCalls
import ThreemaFramework
import UIKit

// MARK: - ConversationTableViewCell.Configuration

extension ConversationTableViewCell {
    private enum Configuration {
        /// The size of the avatar
        static let avatarSize = 56.0
        /// The maximal size of the avatar
        static let maxAvatarSize = 70.0
        
        /// Content margins
        static let contentMargins = 8.0
        
        /// Space between avatar and messageStack
        static let avatarMessageSpace = 15.0
        
        /// Space between name and message stack
        static let nameMessageSpace = 3.0
        
        /// Preview text-style
        static let previewTextStyle: UIFont.TextStyle = .subheadline
        /// DateDraft text-style
        static let dateDraftTextStyle: UIFont.TextStyle = .footnote
        
        /// TitleDateLastMessageState stack view spacing
        static let nameDateLastMessageStateStackViewSpacing = 5.0
        
        /// Distance from center of last message state icon and border
        static let lastMessageStateTrailingDistance = 9.0
        /// Spacing between last message state icon and date
        static let dateLastMessageStateSpacing = 4.0

        /// DateLastMessageState stack view spacing
        static let dateLastMessageStateStackViewSpacing = 5.0
        
        /// Preview stack view horizontal spacing
        static let previewStackViewHorizontalSpacing = 4.0
        /// Preview stack view vertical spacing
        static let previewStackViewVerticalSpacing = 5.0
        
        /// Icons stack view spacing
        static let iconsStackViewSpacing = 2.0
        
        /// Size of Threema Type Icon
        
        static let typeIconSize = 20.0
        /// DisplayState image configuration
        static let displayStateConfiguration = UIImage.SymbolConfiguration(
            textStyle: Configuration.dateDraftTextStyle,
            scale: .small
        )
        
        static let noteGroupConfiguration = UIImage.SymbolConfiguration(
            textStyle: Configuration.dateDraftTextStyle,
            scale: .medium
        )
        
        /// Lock image configuration
        static let lockImageConfiguration = UIImage.SymbolConfiguration(
            textStyle: Configuration.dateDraftTextStyle,
            scale: .medium
        )
        
        /// Icons image configuration
        static let iconsConfiguration = UIImage.SymbolConfiguration(
            textStyle: .body,
            scale: .medium
        )
        
        /// Icons accessibility image configuration
        static let iconsAccessibilityConfiguration = UIImage.SymbolConfiguration(
            textStyle: .body,
            scale: .medium
        )
        
        /// Typing icon image configuration
        static let typingIconConfiguration = UIImage.SymbolConfiguration(
            textStyle: .body,
            scale: .medium
        )
        
        /// Debounce time in milliseconds when updating the cell in reaction to a group call state change
        /// We don't expect these updates to be very frequent but lets be safe.
        static let debounceInMilliseconds = 500
    }
}

final class ConversationTableViewCell: ThemedCodeTableViewCell {
    
    private var conversationObservers = [NSKeyValueObservation]()
    private var lastMessageObservers = [NSKeyValueObservation]()
    private var groupImageObservers = [NSKeyValueObservation]()
    private var contactObservers = [NSKeyValueObservation]()
    private var groupCallButtonBannerObserver: AnyCancellable?
    
    private var cancellables = Set<AnyCancellable>()
    
    private let businessInjector = BusinessInjector()
    
    private lazy var constantScaler = UIFontMetrics(forTextStyle: Configuration.dateDraftTextStyle)

    /// Offset of date label from trailing end
    private lazy var dateLabelTrailingInset: CGFloat = {
        // The date label is as far away from the symbol center as its center is form the trailing end plus the space
        let offset = 2 * statusSymbolXCenterTrailingDistance // This is already scaled
        let scaledSpace = constantScaler.scaledValue(
            for: Configuration.dateLastMessageStateSpacing
        )
        
        return offset + scaledSpace
    }()
    
    /// Distance of symbol center from trailing end
    private lazy var statusSymbolXCenterTrailingDistance: CGFloat = constantScaler.scaledValue(
        // Adapt for content size categories
        for: Configuration.lastMessageStateTrailingDistance
    )
    
    /// The scaled size of the avatar
    private lazy var scaledAvatarSize: CGFloat = {
        // Adapt for content size categories
        let scaledSize = constantScaler.scaledValue(for: Configuration.avatarSize)
        return scaledSize > Configuration.maxAvatarSize ? Configuration.maxAvatarSize : scaledSize
    }()
    
    // MARK: - Views
    
    /// Avatar of contact or group
    private lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView(image: BundleUtil.imageNamed("Unknown"))
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        
        imageView.accessibilityIgnoresInvertColors = true
        
        return imageView
    }()
    
    private lazy var threemaTypeImageView: UIImageView = {
        let imageView = UIImageView(image: ThreemaUtility.otherThreemaTypeIcon)
        
        imageView.widthAnchor.constraint(equalToConstant: Configuration.typeIconSize).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: Configuration.typeIconSize).isActive = true

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.accessibilityIgnoresInvertColors = true
        
        return imageView
    }()
    
    private lazy var badgeCountView: BadgeCountView = {
        let view = BadgeCountView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .body).bold()
        label.textColor = Colors.text
        label.highlightedTextColor = Colors.text
        label.numberOfLines = 1
        
        if UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory {
            label.numberOfLines = 2
        }
        
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .vertical)

        return label
    }()
    
    private lazy var dateDraftLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: Configuration.dateDraftTextStyle)
        label.textColor = Colors.textLight
        label.highlightedTextColor = Colors.textLight
        label.numberOfLines = 1
        label.textAlignment = .right
        
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        return label
    }()
    
    private lazy var displayStateImageView: UIImageView = {
        let imageView = UIImageView()
        
        imageView.accessibilityIgnoresInvertColors = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        return imageView
    }()
    
    private lazy var previewLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: Configuration.previewTextStyle)
        label.textColor = Colors.textLight
        label.highlightedTextColor = Colors.textLight
        label.numberOfLines = 2
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        label.adjustsFontForContentSizeCategory = true
        
        return label
    }()
    
    /// Button shown when a group call is running in a group
    /// Is used to join a group call but does not create a new call
    private lazy var groupCallJoinButton: UIButton = {
        let action = UIAction { [weak self] _ in
            
            guard let group = self?.group else {
                assertionFailure("Did tap Group Call Join Button but group was nil")
                return
            }
            
            DDLogVerbose("[GroupCall] Group Call Join Button tapped")
            GlobalGroupCallManagerSingleton.shared.startGroupCall(
                in: group,
                intent: .join
            )
        }
        
        var buttonConfig = UIButton.Configuration.bordered()
        let imageConfig = UIImage.SymbolConfiguration(scale: .small)
        buttonConfig.title = BundleUtil.localizedString(forKey: "group_call_join_button_title")
        buttonConfig.buttonSize = .small
        buttonConfig.cornerStyle = .capsule

        let button = UIButton(configuration: buttonConfig, primaryAction: action)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        button.setContentHuggingPriority(.required, for: .horizontal)
        
        return button
    }()
    
    private lazy var typingIndicatorImageView: UIImageView = {
        let image = UIImage(
            systemName: "ellipsis.bubble.fill",
            withConfiguration: Configuration.typingIconConfiguration
        )?
            .withTintColor(Colors.grayCircleBackground, renderingMode: .alwaysOriginal)
        let imageView = UIImageView(
            image: image
        )
        
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        
        if #available(iOS 17, *) {
            imageView.addSymbolEffect(.variableColor.cumulative.dimInactiveLayers)
        }
        
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        imageView.setContentHuggingPriority(.required, for: .horizontal)

        imageView.accessibilityIgnoresInvertColors = true
        
        return imageView
    }()
    
    private lazy var dndImageView: UIImageView = {
        let imageView = UIImageView(
            image: UIImage(
                systemName: "bell.fill",
                withConfiguration: Configuration.iconsConfiguration
            )?
                .withTintColor(Colors.grayCircleBackground, renderingMode: .alwaysOriginal)
        )
        
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        imageView.setContentHuggingPriority(.required, for: .horizontal)

        imageView.accessibilityIgnoresInvertColors = true
        
        return imageView
    }()
    
    private lazy var pinImageView: UIImageView = {
        let image = UIImage(
            systemName: "pin.circle.fill",
            withConfiguration: Configuration.iconsConfiguration
        )?
            .withTintColor(Colors.backgroundPinChat, renderingMode: .alwaysOriginal)
        let imageView = UIImageView(
            image: image
        )
        
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        
        imageView.accessibilityIgnoresInvertColors = true
        
        return imageView
    }()

    private lazy var nameDateLastMessageStateStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [nameLabel, dateLastMessageStateContainerView])
        stackView.spacing = Configuration.nameDateLastMessageStateStackViewSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.setContentCompressionResistancePriority(.required, for: .vertical)
        stackView.alignment = .lastBaseline
        if traitCollection.preferredContentSizeCategory >= .accessibilityMedium {
            stackView.axis = .vertical
            stackView.alignment = .leading
        }
        
        return stackView
    }()
    
    private lazy var dateLastMessageStateContainerView: UIView = {
        let containerView = UIView(frame: .zero)
        containerView.addSubview(dateDraftLabel)
        containerView.addSubview(displayStateImageView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        return containerView
    }()
    
    private lazy var previewStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [previewLabel])
        stackView.alignment = .top
        stackView.spacing = Configuration.previewStackViewHorizontalSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            stackView.axis = .vertical
            stackView.alignment = .leading
            stackView.spacing = Configuration.previewStackViewVerticalSpacing
        }
        
        return stackView
    }()
    
    private lazy var iconsStackView: UIStackView = {
        let stackView =
            UIStackView(arrangedSubviews: [dndImageView, pinImageView, typingIndicatorImageView, groupCallJoinButton])
        stackView.axis = .horizontal
        stackView.spacing = Configuration.iconsStackViewSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        stackView.setContentHuggingPriority(.required, for: .horizontal)
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            stackView.alignment = .leading
        }
        
        return stackView
    }()
    
    deinit {
        removeAllObjectObservers()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Internal state
    
    private(set) var conversation: Conversation? {
        willSet {
            removeAllObjectObservers()
            group = nil
            
            groupCallButtonBannerObserver?.cancel()
            groupCallButtonBannerObserver = nil
        }
        didSet {
            guard let conversation else {
                return
            }
            
            if conversation.isGroup() {
                group = businessInjector.groupManager.getGroup(conversation: conversation)
            }
            
            updateCell()
            Task { @MainActor in
                await updateGroupCallButton(
                    GlobalGroupCallManagerSingleton.shared.globalGroupCallObserver
                        .getCurrentItem()
                )
            }
        }
    }
    
    private var group: Group?

    private(set) var navigationController: UINavigationController?
    
    private var groupCallGroupModel: GroupCallThreemaGroupModel?

    // MARK: - Configuration
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        updateColors()
    }
    
    override func configureCell() {
        super.configureCell()
        
        typingIndicatorImageView.isHidden = true
        dndImageView.isHidden = true
        pinImageView.isHidden = true
        groupCallJoinButton.isHidden = true
                
        contentView.addSubview(avatarImageView)
        contentView.addSubview(nameDateLastMessageStateStackView)
        contentView.addSubview(previewStackView)
        contentView.addSubview(iconsStackView)
        contentView.addSubview(badgeCountView)
        contentView.addSubview(threemaTypeImageView)

        let margins = contentView.layoutMarginsGuide
        
        NSLayoutConstraint.activate([
            
            // DateLastMessageStateContainerView
            dateDraftLabel.topAnchor.constraint(equalTo: dateLastMessageStateContainerView.topAnchor),
            dateDraftLabel.leadingAnchor.constraint(equalTo: dateLastMessageStateContainerView.leadingAnchor),
            dateDraftLabel.bottomAnchor.constraint(equalTo: dateLastMessageStateContainerView.bottomAnchor),
            dateDraftLabel.trailingAnchor.constraint(
                equalTo: dateLastMessageStateContainerView.trailingAnchor,
                constant: -dateLabelTrailingInset
            ),
            
            displayStateImageView.centerXAnchor.constraint(
                equalTo: dateLastMessageStateContainerView.trailingAnchor,
                constant: -statusSymbolXCenterTrailingDistance
            ),
            
            // Avatar
            avatarImageView.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            avatarImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarImageView.heightAnchor.constraint(equalToConstant: scaledAvatarSize),
            avatarImageView.widthAnchor.constraint(equalTo: avatarImageView.heightAnchor),
            
            // Name, Date, Message State
            nameDateLastMessageStateStackView.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: Configuration.contentMargins
            ),
            nameDateLastMessageStateStackView.leadingAnchor.constraint(
                equalTo: avatarImageView.trailingAnchor,
                constant: Configuration.avatarMessageSpace
            ),
            nameDateLastMessageStateStackView.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            
            // Preview
            previewStackView.topAnchor.constraint(
                equalTo: nameDateLastMessageStateStackView.bottomAnchor,
                constant: Configuration.nameMessageSpace
            ),
            previewStackView.leadingAnchor.constraint(
                equalTo: avatarImageView.trailingAnchor,
                constant: Configuration.avatarMessageSpace
            ),
            previewStackView.bottomAnchor.constraint(
                lessThanOrEqualTo: contentView.bottomAnchor,
                constant: -Configuration.contentMargins
            ),
            previewStackView.trailingAnchor.constraint(
                equalTo: iconsStackView.leadingAnchor,
                constant: -Configuration.previewStackViewHorizontalSpacing
            ),
            
            previewStackView.heightAnchor.constraint(equalToConstant: height()),
            
            // Icons
            iconsStackView.topAnchor.constraint(
                equalTo: nameDateLastMessageStateStackView.bottomAnchor,
                constant: Configuration.nameMessageSpace
            ),
            iconsStackView.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            iconsStackView.bottomAnchor.constraint(
                equalTo: previewStackView.bottomAnchor
            ),
            
            // Avatar badges
            badgeCountView.topAnchor.constraint(equalTo: avatarImageView.topAnchor),
            badgeCountView.trailingAnchor.constraint(equalTo: avatarImageView.trailingAnchor),
            
            threemaTypeImageView.bottomAnchor.constraint(equalTo: avatarImageView.bottomAnchor),
            threemaTypeImageView.leadingAnchor.constraint(equalTo: avatarImageView.leadingAnchor),
        ])
        
        if UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory {
            displayStateImageView.firstBaselineAnchor.constraint(equalTo: dateDraftLabel.firstBaselineAnchor)
                .isActive = true
        }
        else {
            displayStateImageView.firstBaselineAnchor.constraint(equalTo: nameLabel.firstBaselineAnchor).isActive = true
        }
        
        registerGlobalObservers()
    }
    
    // MARK: - Public functions
    
    /// Set the conversation that is displayed in this cell
    ///
    /// - Parameter conversation: Conversation that is shown in this cell
    func setConversation(to conversation: Conversation?) {
        self.conversation = conversation
    }
    
    /// UINavigationController of the TableView this cell is displayed in
    ///
    /// - Parameter navigationController: UINavigationController of the TableView this cell is displayed in
    func setNavigationController(to navigationController: UINavigationController?) {
        self.navigationController = navigationController
    }
    
    public func updateLastMessagePreview() {
        updateAccessibility()

        guard let conversation else {
            previewLabel.attributedText = nil
            dateDraftLabel.text = nil
            return
        }

        // Show lock icon for private chats
        guard conversation.conversationCategory != .private else {
            previewLabel
                .attributedText = NSAttributedString(string: BundleUtil.localizedString(forKey: "private_chat_label"))
            dateDraftLabel.text = nil
            return
        }
        
        updateDateDraftLabel()
    }
    
    // MARK: - Updates
    
    override func updateColors() {
        super.updateColors()
        
        backgroundColor = .clear
        
        if let conversation,
           !conversation.isGroup(),
           let contact = conversation.contact,
           let state = contact.state,
           state.intValue == kStateInactive || state.intValue == kStateInvalid {
            nameLabel.textColor = Colors.textLight
            nameLabel.highlightedTextColor = Colors.textLight
        }
        else {
            nameLabel.textColor = Colors.text
            nameLabel.highlightedTextColor = Colors.text
        }
        
        if let conversation {
            let draft = MessageDraftStore.shared.loadDraft(for: conversation)
            updateColorsForDateDraftLabel(isDraft: draft?.string != nil)
        }
        
        previewLabel.textColor = Colors.textLight
        previewLabel.highlightedTextColor = Colors.textLight

        badgeCountView.updateColors()
        
        typingIndicatorImageView.image = UIImage(
            systemName: "ellipsis.bubble.fill",
            withConfiguration: Configuration.typingIconConfiguration
            
        )?
            .withTintColor(Colors.grayCircleBackground, renderingMode: .alwaysOriginal)
        
        let iconConfig = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ?
            Configuration.iconsAccessibilityConfiguration
            : Configuration.iconsConfiguration
        let pinImage = UIImage(
            systemName: "pin.circle.fill",
            withConfiguration: iconConfig
        )?
            .withTintColor(Colors.backgroundPinChat, renderingMode: .alwaysOriginal)
        pinImageView.image = pinImage
        
        updateDisplayStateImage()
        updateTypingIndicator()
        updateDndImage()
        updatePinImage()
        
        threemaTypeImageView.image = ThreemaUtility.otherThreemaTypeIcon
    }
    
    func height() -> CGFloat {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: Configuration.previewTextStyle)
        label.numberOfLines = 2

        label.adjustsFontForContentSizeCategory = true
                
        label.text = "\n"
                
        return label.sizeThatFits(CGSize(width: CGFLOAT_MAX, height: CGFLOAT_MAX)).height
    }
    
    private func updateSeparatorInset() {
        guard !traitCollection.preferredContentSizeCategory.isAccessibilityCategory else {
            separatorInset = .zero
            return
        }
        
        Task { @MainActor in
            let leftSeparatorInset = avatarImageView.frame.size.width + Configuration.avatarMessageSpace
            separatorInset = UIEdgeInsets(top: 0, left: leftSeparatorInset, bottom: 0, right: 0)
        }
    }
    
    private func updateColorsForDateDraftLabel(isDraft: Bool) {
        if isDraft {
            dateDraftLabel.textColor = Colors.red
            dateDraftLabel.highlightedTextColor = Colors.red
        }
        else {
            dateDraftLabel.textColor = Colors.textLight
            dateDraftLabel.highlightedTextColor = Colors.textLight
        }
    }
    
    private func updateCell() {
        
        guard let conversation else {
            return
        }
        
        updateTitleLabel()
        updateBadge()
        updateLastMessagePreview()
        
        updateDisplayStateImage()
        
        updateDndImage()
        
        updatePinImage()
                
        loadAvatar()
        
        if !conversation.isGroup(),
           let contact = conversation.contact {
            threemaTypeImageView.isHidden = !contact.showOtherThreemaTypeIcon
        }
        else {
            threemaTypeImageView.isHidden = true
        }
        
        if conversation.isGroup(), businessInjector.settingsStore.enableThreemaGroupCalls {
            updateGroupCallButton()
        }
        else {
            hideUpdateGroupCallButton()
        }
        
        addAllObjectObservers()
    }
    
    private func updateGroupCallButton() {
        
        guard businessInjector.settingsStore.enableThreemaGroupCalls else {
            hideUpdateGroupCallButton()
            assertionFailure()
            return
        }
        
        Task {
            groupCallButtonBannerObserver = GlobalGroupCallManagerSingleton.shared.globalGroupCallObserver.publisher
                .pub
                .filter { [weak self] update in
                    guard let strongSelf = self, let conversation = strongSelf.conversation else {
                        return false
                    }
                    
                    var isEqual: Bool?
                    strongSelf.businessInjector.entityManager.performBlockAndWait {
                        guard let tempConversation = strongSelf.businessInjector.entityManager.entityFetcher
                            .existingObject(with: conversation.objectID) as? Conversation else {
                            return
                        }
                        isEqual = tempConversation.isEqualTo(
                            groupIdentity: update.groupIdentity,
                            myIdentity: strongSelf.businessInjector.myIdentityStore.identity
                        )
                    }
                    
                    return isEqual ?? false
                }
                .sink { [weak self] update in
                    Task { @MainActor in
                        self?.updateGroupCallButton(update)
                    }
                }
        }
    }
    
    private func updateGroupCallButton(_ update: GroupCallBannerButtonUpdate?) {
        
        guard let update,
              update.groupIdentity.id == conversation?.groupID else {
            hideUpdateGroupCallButton()
            return
        }
        
        if update.hideComponent {
            hideUpdateGroupCallButton()
        }
        else {
            let text = update.joinState == .joined ? BundleUtil
                .localizedString(forKey: "group_call_open_button_title") : BundleUtil
                .localizedString(forKey: "group_call_join_button_title")
            groupCallJoinButton.configuration?.title = text
            groupCallJoinButton.isHidden = false
        }
        updateIconStackView()
    }
    
    private func hideUpdateGroupCallButton() {
        groupCallJoinButton.isHidden = true
        groupCallJoinButton.configuration?.title = BundleUtil
            .localizedString(forKey: "group_call_join_button_title")
    }
    
    private func updateTitleLabel() {
        guard let conversation,
              let displayName = conversation.displayName else {
            // This should not occur, but we assign an empty string to make the firstBaseline alignment of
            // dateDraftLabel work anyways.
            nameLabel.attributedText = NSAttributedString(string: " ")
            return
        }
        
        guard !conversation.isGroup() else {
            // Group conversation
            if let group,
               !group.isSelfMember {
                let attributeString = NSMutableAttributedString(string: displayName)
                attributeString.addAttribute(
                    .strikethroughStyle,
                    value: 2,
                    range: NSMakeRange(0, attributeString.length)
                )
                nameLabel.attributedText = attributeString
            }
            else {
                nameLabel.attributedText = NSMutableAttributedString(string: displayName)
            }
            nameLabel.textColor = Colors.text
            nameLabel.highlightedTextColor = Colors.text
            return
        }
        
        // Check style for the title
        if let contact = conversation.contact,
           let state = contact.state,
           state.intValue == kStateInvalid {
            // Contact is invalid
            let attributeString = NSMutableAttributedString(string: displayName)
            attributeString.addAttribute(.strikethroughStyle, value: 2, range: NSMakeRange(0, attributeString.length))
            nameLabel.attributedText = attributeString
            nameLabel.textColor = Colors.textLight
            nameLabel.highlightedTextColor = Colors.textLight
        }
        else if let contact = conversation.contact,
                UserSettings.shared().blacklist.contains(contact.identity) {
            // Contact is blacklisted
            nameLabel.attributedText = NSMutableAttributedString(string: "🚫 " + displayName)
        }
        else {
            nameLabel.attributedText = NSMutableAttributedString(string: displayName)
            nameLabel.textColor = Colors.text
            nameLabel.highlightedTextColor = Colors.text
        }
    }
    
    private func updateDisplayStateImage() {
        guard let conversation else {
            displayStateImageView.isHidden = true
            return
        }
        
        // Show lock icon for private chats
        guard conversation.conversationCategory != .private else {
            displayStateImageView.image = UIImage(
                systemName: "lock.fill",
                withConfiguration: Configuration.lockImageConfiguration
            )?
                .withTintColor(Colors.grayCircleBackground, renderingMode: .alwaysOriginal)
            displayStateImageView.isHidden = false
            return
        }
        
        // Groups
        if conversation.isGroup() {
            // Check is group a note group
            if let group,
               group.isNoteGroup {
                displayStateImageView.image = UIImage(
                    systemName: "note.text",
                    withConfiguration: Configuration.noteGroupConfiguration
                )?
                    .withTintColor(Colors.grayCircleBackground, renderingMode: .alwaysOriginal)
            }
            else {
                displayStateImageView.image = UIImage(
                    systemName: "person.3.fill",
                    withConfiguration: Configuration.displayStateConfiguration
                )?
                    .withTintColor(Colors.grayCircleBackground, renderingMode: .alwaysOriginal)
            }
            displayStateImageView.isHidden = false
            return
        }
        // Distribution list
        else if conversation.distributionList != nil {
            displayStateImageView.image = UIImage(
                systemName: "megaphone.fill",
                withConfiguration: Configuration.displayStateConfiguration
            )?
                .withTintColor(Colors.grayCircleBackground, renderingMode: .alwaysOriginal)
            displayStateImageView.isHidden = false
            return
        }
        // 1:1
        else {
            if let lastMessage = conversation.lastMessage,
               lastMessage.deletedAt == nil,
               let symbol = lastMessage.messageDisplayState.overviewSymbol(
                   with: Colors.grayCircleBackground,
                   ownMessage: lastMessage.isOwnMessage,
                   configuration: Configuration.displayStateConfiguration
               ) {
                displayStateImageView.isHidden = false
                displayStateImageView.image = symbol
                return
            }
            
            displayStateImageView.isHidden = true
        }
    }
    
    private func updateDateDraftLabel() {
        guard let conversation else {
            dateDraftLabel.isHidden = true
            return
        }
        
        if let draft = MessageDraftStore.shared.previewForDraft(
            for: conversation,
            textStyle: Configuration.dateDraftTextStyle,
            tint: Colors.textLight
        ) {
            updateColorsForDateDraftLabel(isDraft: true)
            dateDraftLabel.text = BundleUtil.localizedString(forKey: "draft").uppercased()
            previewLabel.attributedText = draft
        }
        else {
            updateColorsForDateDraftLabel(isDraft: false)
            
            guard let lastMessage = conversation.lastMessage else {
                previewLabel.attributedText = nil
                dateDraftLabel.text = nil
                return
            }
            
            dateDraftLabel.text = DateFormatter.relativeTimeTodayAndMediumDateOtherwise(for: lastMessage.displayDate)
            if conversation.conversationCategory != .private {
                if let previewableMessage = lastMessage as? PreviewableMessage {
                    previewLabel.attributedText = previewableMessage
                        .previewAttributedText(for: PreviewableMessageConfiguration.conversationCell)
                }
            }
            else {
                previewLabel.attributedText = NSAttributedString(
                    string: BundleUtil.localizedString(forKey: "private_chat_label")
                )
            }
        }
        dateDraftLabel.isHidden = false
    }
    
    private func updateBadge() {
        guard let conversation else {
            badgeCountView.isHidden = true
            return
        }
        let badgeCount = conversation.unreadMessageCount.intValue
        
        guard badgeCount != 0 else {
            badgeCountView.isHidden = true
            return
        }
        
        let badgeCountString = badgeCount > 0 ? String(badgeCount) : ""
        badgeCountView.updateCountLabel(to: badgeCountString)
        badgeCountView.isHidden = false
    }
    
    private func updateTypingIndicator() {
        var isTyping = false
        
        if let conversation,
           !conversation.isGroup(),
           conversation.conversationCategory != .private {
            isTyping = conversation.typing.boolValue
        }
        
        typingIndicatorImageView.isHidden = !isTyping
        updateIconStackView()
    }
    
    private func updateDndImage(with newPushSetting: PushSetting? = nil) {
        guard let conversation, conversation.contact != nil || group != nil else {
            dndImageView.image = nil
            dndImageView.isHidden = true
            updateIconStackView()
            return
        }
        
        let pushSetting = newPushSetting ?? getPushSetting()
        let iconConfig = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ?
            Configuration.iconsAccessibilityConfiguration
            : Configuration.iconsConfiguration
        if let icon = pushSetting.imageForEditedPushSetting(with: iconConfig) {
            dndImageView.image = icon.withTintColor(Colors.grayCircleBackground, renderingMode: .alwaysOriginal)
            dndImageView.isHidden = false
        }
        else {
            dndImageView.image = nil
            dndImageView.isHidden = true
        }
        updateIconStackView()
    }
    
    private func updatePinImage() {
        guard let conversation,
              conversation.conversationVisibility == .pinned else {
            pinImageView.isHidden = true
            updateIconStackView()
            return
        }
        
        pinImageView.isHidden = false
        updateIconStackView()
    }
       
    private func updateIconStackView() {
        iconsStackView.isHidden = dndImageView.isHidden && pinImageView.isHidden && typingIndicatorImageView
            .isHidden && groupCallJoinButton.isHidden
    }
    
    private func updateAccessibility() {
        guard let conversation, conversation.contact != nil || group != nil else {
            return
        }

        var accessibilityText = "\(nameLabel.text ?? ""). "

        var pushSetting = getPushSetting()
        if pushSetting.type == .on,
           pushSetting.muted {
            accessibilityText +=
                "\(BundleUtil.localizedString(forKey: "notification_sound_header")) \(BundleUtil.localizedString(forKey: "doNotDisturb_off")). "
        }
        else if pushSetting.type == .off,
                !pushSetting.mentioned {
            accessibilityText +=
                "\(BundleUtil.localizedString(forKey: "doNotDisturb_title")) \(BundleUtil.localizedString(forKey: "doNotDisturb_on")). "
        }
        else if pushSetting.type == .off,
                pushSetting.mentioned {
            accessibilityText +=
                "\(BundleUtil.localizedString(forKey: "doNotDisturb_title")) \(BundleUtil.localizedString(forKey: "doNotDisturb_on")), \(BundleUtil.localizedString(forKey: "doNotDisturb_mention")). "
        }
        else if pushSetting.type == .offPeriod,
                !pushSetting.mentioned {
            accessibilityText +=
                "\(BundleUtil.localizedString(forKey: "doNotDisturb_title")) \(BundleUtil.localizedString(forKey: "doNotDisturb_onPeriod_time")) \(DateFormatter.getFullDate(for: pushSetting.periodOffTillDate)). "
        }
        else if pushSetting.type == .offPeriod,
                pushSetting.mentioned {
            accessibilityText +=
                "\(BundleUtil.localizedString(forKey: "doNotDisturb_title")) \(BundleUtil.localizedString(forKey: "doNotDisturb_onPeriod_time")) \(DateFormatter.getFullDate(for: pushSetting.periodOffTillDate)), \(BundleUtil.localizedString(forKey: "doNotDisturb_mention"))"
        }
        
        if let draft = MessageDraftStore.shared.loadDraft(for: conversation)?.string {
            // Drafts
            updateAccessibility(with: draft, accessibilityString: accessibilityText)
            return
        }
        
        if conversation.conversationCategory == .private {
            accessibilityText += "\(BundleUtil.localizedString(forKey: "private_chat_accessibility")). "
            if conversation.unreadMessageCount.intValue > 0 {
                accessibilityText += "\(BundleUtil.localizedString(forKey: "unread")). "
            }
            accessibilityLabel = accessibilityText
            return
        }
        
        if let lastMessage = conversation.lastMessage as? PreviewableMessage {
            accessibilityText += "\(DateFormatter.accessibilityRelativeDayTime(lastMessage.displayDate)). "
            
            if conversation.unreadMessageCount.intValue > 0 {
                accessibilityText += "\(BundleUtil.localizedString(forKey: "unread")). "
            }
            if let sender = lastMessage.accessibilityMessageSender {
                accessibilityText += "\(BundleUtil.localizedString(forKey: "from")) "
                accessibilityText += "\(sender). "
            }
            accessibilityText += "\(lastMessage.previewText). "
        }
        
        if conversation.conversationVisibility == .pinned {
            accessibilityText += "\(BundleUtil.localizedString(forKey: "pinned_conversation"))."
        }
        accessibilityLabel = accessibilityText
    }
    
    private func updateAccessibility(with draft: String, accessibilityString: String) {
        guard let conversation else {
            return
        }
        
        var accessibilityText = accessibilityString
        if conversation.conversationCategory == .private {
            accessibilityText += "\(BundleUtil.localizedString(forKey: "private_chat_accessibility")). "
            if conversation.unreadMessageCount.intValue > 0 {
                accessibilityText += "\(BundleUtil.localizedString(forKey: "unread")). "
            }
            accessibilityLabel = accessibilityText
            return
        }
        
        if conversation.unreadMessageCount.intValue > 0 {
            accessibilityText += "\(BundleUtil.localizedString(forKey: "unread")). "
        }
        
        accessibilityText += "\(BundleUtil.localizedString(forKey: "draft")). "
        accessibilityText += "\(draft). "
        
        accessibilityLabel = accessibilityText
    }
    
    private func loadAvatar() {
        
        AvatarMaker.shared().avatar(
            for: conversation,
            size: scaledAvatarSize,
            masked: true
        ) { avatarImage, objectID in
            
            guard objectID == self.conversation?.objectID else {
                return
            }
            
            Task { @MainActor in
                if let avatarImage {
                    self.avatarImageView.image = avatarImage
                }
                else {
                    self.avatarImageView.image = BundleUtil.imageNamed("Unknown")
                }
                self.updateSeparatorInset()
            }
        }
    }

    private func getPushSetting() -> PushSetting {
        if let group {
            group.pushSetting
        }
        else if let contact = conversation?.contact {
            businessInjector.pushSettingManager.find(forContact: contact.threemaIdentity)
        }
        else {
            fatalError("No push settings for conversation found")
        }
    }

    // MARK: Observers
    
    private func registerGlobalObservers() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name(rawValue: kNotificationChangedPushSetting),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let strongSelf = self, let pushSetting = notification.object as? PushSetting else {
                return
            }

            if let group = strongSelf.group {
                guard pushSetting.groupIdentity == group.groupIdentity else {
                    return
                }
            }
            else if let contact = strongSelf.conversation?.contact {
                guard pushSetting.identity == contact.threemaIdentity else {
                    return
                }
            }
            else {
                return
            }

            strongSelf.updateDndImage(with: pushSetting)
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name(rawValue: kNotificationUpdateDraftForCell),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let strongSelf = self else {
                return
            }
            
            if let conversation = notification.userInfo?[kKeyConversation] as? Conversation,
               conversation.objectID == self?.conversation?.objectID {
                strongSelf.updateLastMessagePreview()
                strongSelf.updateColors()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIContentSizeCategory.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.updateCell()
            strongSelf.layoutSubviews()
        }
    }
    
    private func addAllObjectObservers() {
        observeConversation(\.lastMessage, callOnCreation: false) { [weak self] in

            self?.removeLastMessageObservers()
            self?.observeLastMessageProperties()
            self?.updateTitleLabel()
            self?.updateLastMessagePreview()
            self?.updateDisplayStateImage()
        }

        observeConversation(\.typing, callOnCreation: false) { [weak self] in
            self?.updateTypingIndicator()
        }

        observeConversation(\.conversationVisibility, callOnCreation: false) { [weak self] in
            self?.updatePinImage()
        }

        observeConversation(\.conversationCategory, callOnCreation: false) { [weak self] in
            self?.updateDisplayStateImage()
            self?.updateLastMessagePreview()
        }

        observeConversation(\.unreadMessageCount, callOnCreation: false) { [weak self] in
            self?.updateBadge()
        }

        observeLastMessageProperties()
        
        observeGroupImageProperties()
        
        observeConversation(\.displayName, callOnCreation: false) { [weak self] in
            self?.updateTitleLabel()
        }

        observeConversation(\.groupName, callOnCreation: false) { [weak self] in
            self?.updateTitleLabel()
        }
        observeConversation(\.groupImage, callOnCreation: true) { [weak self] in
            self?.loadAvatar()
            self?.removeGroupImageObservers()
            self?.observeGroupImageProperties()
        }

        observeContact(\.imageData, callOnCreation: false) { [weak self] in
            self?.loadAvatar()
        }

        observeContact(\.contactImage, callOnCreation: false) { [weak self] in
            self?.loadAvatar()
        }

        if businessInjector.settingsStore.enableThreemaGroupCalls {
            // This will be automatically removed on de-init
            startGroupCallObserver()
        }
    }
    
    private func observeLastMessageProperties() {
        if let lastMessage = conversation?.lastMessage as? BaseMessage {
            observeLastMessage(lastMessage, keyPath: \.deletedAt, callOnCreation: false) { [weak self] in
                self?.updateLastMessagePreview()
                self?.updateDisplayStateImage()
            }
        }

        if let lastMessage = conversation?.lastMessage as? BallotMessage {
            observeLastMessage(lastMessage, keyPath: \.ballot, callOnCreation: false) { [weak self] in
                self?.updateLastMessagePreview()
            }
        }
        else if let lastMessage = conversation?.lastMessage as? TextMessage {
            observeLastMessage(lastMessage, keyPath: \.text, callOnCreation: false) { [weak self] in
                self?.updateLastMessagePreview()
            }
        }
        else if let lastMessage = conversation?.lastMessage as? FileMessageEntity {
            observeLastMessage(lastMessage, keyPath: \.mimeType, callOnCreation: false) { [weak self] in
                self?.updateLastMessagePreview()
            }

            observeLastMessage(lastMessage, keyPath: \.caption, callOnCreation: false) { [weak self] in
                self?.updateLastMessagePreview()
            }
        }

        if let conversation,
           conversation.isGroup() {
            return
        }

        if let lastMessage = conversation?.lastMessage {
            observeLastMessage(lastMessage, keyPath: \.userack, callOnCreation: false) { [weak self] in
                self?.updateDisplayStateImage()
                self?.updateDateDraftLabel()
            }

            observeLastMessage(lastMessage, keyPath: \.read, callOnCreation: false) { [weak self] in
                self?.updateDisplayStateImage()
                self?.updateDateDraftLabel()
            }

            observeLastMessage(lastMessage, keyPath: \.delivered, callOnCreation: false) { [weak self] in
                self?.updateDisplayStateImage()
                self?.updateDateDraftLabel()
            }

            observeLastMessage(lastMessage, keyPath: \.sendFailed, callOnCreation: false) { [weak self] in
                self?.updateDisplayStateImage()
                self?.updateDateDraftLabel()
            }

            observeLastMessage(lastMessage, keyPath: \.sent, callOnCreation: false) { [weak self] in
                self?.updateDisplayStateImage()
                self?.updateDateDraftLabel()
            }
        }
    }
    
    private func observeGroupImageProperties() {
        if let groupImage = conversation?.groupImage as? ImageData {
            observeGroupImage(groupImage, keyPath: \.data, callOnCreation: false) {
                AvatarMaker.shared().resetContext()
                self.loadAvatar()
            }
        }
    }
    
    /// Helper to add observers to the `conversation` property
    ///
    /// All observers are stored in the `observers` property.
    ///
    /// - Parameters:
    ///   - keyPath: Key path in `conversation` to observe
    ///   - callOnCreation: Should the handler be called during observer creation?
    ///   - changeHandler: Handler called on each observed change.
    ///                     Don't forget to capture `self` weakly! Dispatched on the main queue.
    private func observeConversation(
        _ keyPath: KeyPath<Conversation, some Any>,
        callOnCreation: Bool = true,
        changeHandler: @escaping () -> Void
    ) {
        
        guard let conversation else {
            return
        }
        let options: NSKeyValueObservingOptions = callOnCreation ? .initial : []
        
        let observer = conversation.observe(keyPath, options: options) { _, _ in
            // Because `changeHandler` updates UI elements we need to ensure that it runs on the main queue
            DispatchQueue.main.async(execute: changeHandler)
        }
        
        conversationObservers.append(observer)
    }
    
    /// Helper to add observers to the `lastMessage` property
    ///
    /// All observers are stored in the `observers` property.
    ///
    /// - Parameters:
    ///   - lastMessage: Message set as `Conversation.lastMessage`
    ///   - keyPath: Key path depending of type `lastMessage` to observe
    ///   - callOnCreation: Should the handler be called during observer creation?
    ///   - changeHandler: Handler called on each observed change.
    ///                     Don't forget to capture `self` weakly! Dispatched on the main queue.
    private func observeLastMessage<Message: BaseMessage>(
        _ lastMessage: Message,
        keyPath: KeyPath<Message, some Any>,
        callOnCreation: Bool = true,
        changeHandler: @escaping () -> Void
    ) {
        let options: NSKeyValueObservingOptions = callOnCreation ? .initial : []

        let observer = lastMessage.observe(keyPath, options: options) { _, _ in
            // Because `changeHandler` updates UI elements we need to ensure that it runs on the main queue
            DispatchQueue.main.async(execute: changeHandler)
        }

        lastMessageObservers.append(observer)
    }
    
    /// Helper to add observers to the `groupImage` property
    ///
    /// All observers are stored in the `observers` property.
    ///
    /// - Parameters:
    ///   - groupImage: ImageData set as `Conversation.groupImage`
    ///   - keyPath: Key path depending of type `groupImage` to observe
    ///   - callOnCreation: Should the handler be called during observer creation?
    ///   - changeHandler: Handler called on each observed change.
    ///                     Don't forget to capture `self` weakly! Dispatched on the main queue.
    private func observeGroupImage(
        _ groupImage: ImageData,
        keyPath: KeyPath<ImageData, some Any>,
        callOnCreation: Bool = true,
        changeHandler: @escaping () -> Void
    ) {
        let options: NSKeyValueObservingOptions = callOnCreation ? .initial : []

        let observer = groupImage.observe(keyPath, options: options) { _, _ in
            // Because `changeHandler` updates UI elements we need to ensure that it runs on the main queue
            DispatchQueue.main.async(execute: changeHandler)
        }

        groupImageObservers.append(observer)
    }

    /// Helper to add observers to the `contact` property
    ///
    /// All observers are stored in the `observers` property.
    ///
    /// - Parameters:
    ///   - keyPath: Key path in `Contact` to observe
    ///   - callOnCreation: Should the handler be called during observer creation?
    ///   - changeHandler: Handler called on each observed change.
    ///                     Don't forget to capture `self` weakly! Dispatched on the main queue.
    private func observeContact(
        _ keyPath: KeyPath<ContactEntity, some Any>,
        callOnCreation: Bool = true,
        changeHandler: @escaping () -> Void
    ) {
        
        guard let contact = conversation?.contact else {
            return
        }
        let options: NSKeyValueObservingOptions = callOnCreation ? .initial : []
        
        let observer = contact.observe(keyPath, options: options) { _, _ in
            // Because `changeHandler` updates UI elements we need to ensure that it runs on the main queue
            DispatchQueue.main.async(execute: changeHandler)
        }
        
        contactObservers.append(observer)
    }
    
    private func removeAllObjectObservers() {
        removeConversationObservers()
        removeContactObservers()
        removeLastMessageObservers()
        removeGroupImageObservers()
    }
    
    private func removeConversationObservers() {
        // Invalidate all observers
        for observer in conversationObservers {
            observer.invalidate()
        }
        
        // Remove them so we don't reference old observers
        conversationObservers.removeAll()
    }
    
    private func removeLastMessageObservers() {
        // Invalidate all observers
        for observer in lastMessageObservers {
            observer.invalidate()
        }
        
        // Remove them so we don't reference old observers
        lastMessageObservers.removeAll()
    }
    
    private func removeGroupImageObservers() {
        // Invalidate all observers
        for observer in groupImageObservers {
            observer.invalidate()
        }
        
        // Remove them so we don't reference old observers
        groupImageObservers.removeAll()
    }
    
    private func removeContactObservers() {
        // Invalidate all observers
        for observer in contactObservers {
            observer.invalidate()
        }
        
        // Remove them so we don't reference old observers
        contactObservers.removeAll()
    }
}

// MARK: - Group Calls

extension ConversationTableViewCell {
    /// Starts observing started or ended group calls and updates the cell respectively
    ///
    /// Note that we don't need to remove this as they will automatically be removed on deallocation
    private func startGroupCallObserver() {
        guard businessInjector.settingsStore.enableThreemaGroupCalls else {
            assertionFailure()
            return
        }
        
        guard let conversation,
              conversation.isGroup() else {
            return
        }
        
        GlobalGroupCallManagerSingleton.shared.globalGroupCallObserver.publisher.pub
            // We'd rather filter on some other queue, but the conversation is loaded on the main thread and
            // checking on
            // another thread will cause CD concurrency issues.
            .receive(on: DispatchQueue.main)
            .filter { [weak self] in
                self?.currentConversationIsEqualTo(group: $0.groupIdentity.id, $0.groupIdentity.creator.string) ?? false
            }
            .debounce(for: .milliseconds(Configuration.debounceInMilliseconds), scheduler: DispatchQueue.main)
            .sink(receiveValue: { [weak self] _ in
                DDLogVerbose("[GroupCall] Update Conversation Cell for Call")
                self?.updateGroupCallButton()
            }).store(in: &cancellables)
    }
    
    /// Checks whether the current conversation is the group conversation with given groupID and creator
    /// - Parameters:
    ///   - groupID:
    ///   - creator:
    /// - Returns:
    private func currentConversationIsEqualTo(group groupID: Data, _ creator: String) -> Bool {
        guard let conversation else {
            return false
        }
        
        guard conversation.isGroup() else {
            return false
        }
        
        guard conversation.groupID == groupID else {
            return false
        }
        
        if let id = conversation.contact?.identity, id != creator {
            return false
        }
        
        if conversation.contact == nil, businessInjector.myIdentityStore.identity != creator {
            return false
        }
        
        return true
    }
}

// MARK: - Reusable

extension ConversationTableViewCell: Reusable { }
