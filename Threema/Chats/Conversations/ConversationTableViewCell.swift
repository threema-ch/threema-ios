//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

import ThreemaFramework
import UIKit

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
    }
}

final class ConversationTableViewCell: ThemedCodeTableViewCell {
    
    private var conversationObservers = [NSKeyValueObservation]()
    private var lastMessageObservers = [NSKeyValueObservation]()
    private var contactObservers = [NSKeyValueObservation]()
    
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
    private lazy var statusSymbolXCenterTrailingDistance: CGFloat = {
        // Adapt for content size categories
        constantScaler.scaledValue(for: Configuration.lastMessageStateTrailingDistance)
    }()
    
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

        label.adjustsFontForContentSizeCategory = true
        
        return label
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
        
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        imageView.setContentHuggingPriority(.required, for: .horizontal)

        imageView.accessibilityIgnoresInvertColors = true
        
        return imageView
    }()
    
    private lazy var dndImageView: UIImageView = {
        let imageView = UIImageView(
            image: UIImage(
                systemName: "Bell",
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

        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            stackView.axis = .vertical
            stackView.alignment = .leading
            stackView.spacing = Configuration.previewStackViewVerticalSpacing
        }
        
        return stackView
    }()
    
    private lazy var iconsStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [dndImageView, pinImageView, typingIndicatorImageView])
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
        }
        didSet {
            guard conversation != nil else {
                return
            }

            updateCell()
        }
    }
    
    // MARK: - Public functions
    
    /// Set the conversation that is displayed in this cell
    ///
    /// - Parameter conversation: Conversation that is shown in this cell
    func setConversation(to conversation: Conversation?) {
        self.conversation = conversation
    }
    
    // MARK: - Configuration
    
    override func configureCell() {
        super.configureCell()
        
        typingIndicatorImageView.isHidden = true
        dndImageView.isHidden = true
        pinImageView.isHidden = true
                
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
    
    public func updateLastMessagePreview() {
        updateAccessibility()
        
        guard let conversation = conversation else {
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
        
        if let draft = MessageDraftStore.previewForDraft(
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
            if let previewableMessage = lastMessage as? PreviewableMessage {
                previewLabel.attributedText = previewableMessage
                    .previewAttributedText(for: PreviewableMessageConfiguration.conversationCell)
            }
        }
    }
    
    // MARK: - Updates
    
    override func updateColors() {
        super.updateColors()
        
        if let conversation = conversation,
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
        
        let draft = MessageDraftStore.loadDraft(for: conversation)
        updateColorsForDateDraftLabel(isDraft: draft != nil)
        
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
        
        guard let conversation = conversation else {
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
            threemaTypeImageView.isHidden = ThreemaUtility.shouldHideOtherTypeIcon(for: contact)
        }
        else {
            threemaTypeImageView.isHidden = true
        }
        
        addAllObjectObservers()
    }
    
    private func updateTitleLabel() {
        guard let conversation = conversation,
              let displayName = conversation.displayName else {
            // This should not occur, but we assign an empty string to make the firstBaseline alignment of dateDraftLabel work anyways.
            nameLabel.attributedText = NSAttributedString(string: " ")
            return
        }
        
        guard !conversation.isGroup() else {
            // Group conversation
            if let group = BusinessInjector().groupManager.getGroup(conversation: conversation),
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
        }
        else if let contact = conversation.contact,
                UserSettings.shared().blacklist.contains(contact.identity) {
            // Contact is blacklisted
            nameLabel.attributedText = NSMutableAttributedString(string: "🚫 " + displayName)
        }
        else {
            nameLabel.attributedText = NSMutableAttributedString(string: displayName)
        }
    }
    
    private func updateDisplayStateImage() {
        guard let conversation = conversation,
              let lastMessage = conversation.lastMessage else {
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
        
        // Show group icon for groups
        guard !conversation.isGroup() else {
            // Check is group a note group
            let groupManager = GroupManager(entityManager: BusinessInjector().entityManager)
            if let group = groupManager.getGroup(conversation: conversation),
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
        
        if let symbol = lastMessage.messageDisplayState.overviewSymbol(
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
    
    private func updateBadge() {
        guard let conversation = conversation else {
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
        
        if let conversation = conversation,
           !conversation.isGroup(),
           conversation.conversationCategory != .private {
            isTyping = conversation.typing.boolValue
        }
        
        typingIndicatorImageView.isHidden = !isTyping
        updateIconStackView()
    }
    
    private func updateDndImage() {
        guard let conversation = conversation else {
            dndImageView.image = nil
            dndImageView.isHidden = true
            updateIconStackView()
            return
        }
        
        let pushSetting = PushSetting(for: conversation)
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
        guard let conversation = conversation,
              conversation.conversationVisibility == .pinned else {
            pinImageView.isHidden = true
            updateIconStackView()
            return
        }
        
        pinImageView.isHidden = false
        updateIconStackView()
    }
       
    private func updateIconStackView() {
        iconsStackView.isHidden = dndImageView.isHidden && pinImageView.isHidden && typingIndicatorImageView.isHidden
    }
    
    private func updateAccessibility() {
        guard let conversation = conversation else {
            return
        }
        
        var accessibilityText = "\(nameLabel.text ?? ""). "
        
        let pushSetting = PushSetting(for: conversation)
        if pushSetting.type == .on,
           pushSetting.silent {
            accessibilityText +=
                "\(BundleUtil.localizedString(forKey: "notification_sound_header")) \(BundleUtil.localizedString(forKey: "doNotDisturb_off")). "
        }
        else if pushSetting.type == .off,
                !pushSetting.mentions {
            accessibilityText +=
                "\(BundleUtil.localizedString(forKey: "doNotDisturb_title")) \(BundleUtil.localizedString(forKey: "doNotDisturb_on")). "
        }
        else if pushSetting.type == .off,
                pushSetting.mentions {
            accessibilityText +=
                "\(BundleUtil.localizedString(forKey: "doNotDisturb_title")) \(BundleUtil.localizedString(forKey: "doNotDisturb_on")), \(BundleUtil.localizedString(forKey: "doNotDisturb_mention")). "
        }
        else if pushSetting.type == .offPeriod,
                !pushSetting.mentions {
            accessibilityText +=
                "\(BundleUtil.localizedString(forKey: "doNotDisturb_title")) \(BundleUtil.localizedString(forKey: "doNotDisturb_onPeriod_time")) \(DateFormatter.getFullDate(for: pushSetting.periodOffTillDate)). "
        }
        else if pushSetting.type == .offPeriod,
                pushSetting.mentions {
            accessibilityText +=
                "\(BundleUtil.localizedString(forKey: "doNotDisturb_title")) \(BundleUtil.localizedString(forKey: "doNotDisturb_onPeriod_time")) \(DateFormatter.getFullDate(for: pushSetting.periodOffTillDate)), \(BundleUtil.localizedString(forKey: "doNotDisturb_mention"))"
        }
        
        if let draft = MessageDraftStore.loadDraft(for: conversation) {
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
        
        if let lastMessage = conversation.lastMessage,
           let preview = lastMessage.previewText() {
            accessibilityText += "\(DateFormatter.accessibilityRelativeDayTime(lastMessage.displayDate)). "
            
            if conversation.unreadMessageCount.intValue > 0 {
                accessibilityText += "\(BundleUtil.localizedString(forKey: "unread")). "
            }
            if let sender = lastMessage.accessibilityMessageSender {
                accessibilityText += "\(BundleUtil.localizedString(forKey: "from")) "
                accessibilityText += "\(sender). "
            }
            accessibilityText += "\(preview). "
        }
        
        if conversation.conversationVisibility == .pinned {
            accessibilityText += "\(BundleUtil.localizedString(forKey: "pinned_conversation"))."
        }
        accessibilityLabel = accessibilityText
    }
    
    private func updateAccessibility(with draft: String, accessibilityString: String) {
        guard let conversation = conversation else {
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
                if let avatarImage = avatarImage {
                    self.avatarImageView.image = avatarImage
                }
                else {
                    self.avatarImageView.image = BundleUtil.imageNamed("Unknown")
                }
                self.updateSeparatorInset()
            }
        }
    }
    
    // MARK: Observers
    
    private func registerGlobalObservers() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name(rawValue: kNotificationChangedPushSettingsList),
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.updateDndImage()
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name(rawValue: kNotificationIdentityAvatarChanged),
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.loadAvatar()
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name(rawValue: kNotificationUpdateDraftForCell),
            object: nil,
            queue: nil
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
            queue: nil
        ) { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.updateCell()
            strongSelf.layoutSubviews()
        }
    }
    
    private func addAllObjectObservers() {
        observeConversation(\.lastMessage, callOnCreation: false) {

            self.removeLastMessageObservers()
            self.observeLastMessageProperties()
            self.updateTitleLabel()
            self.updateLastMessagePreview()
            self.updateDisplayStateImage()
        }

        observeConversation(\.typing, callOnCreation: false) {
            self.updateTypingIndicator()
        }
        
        observeConversation(\.conversationVisibility, callOnCreation: false) {
            self.updatePinImage()
        }
                
        observeConversation(\.conversationCategory, callOnCreation: false) {
            self.updateDisplayStateImage()
            self.updateLastMessagePreview()
        }
        
        observeConversation(\.unreadMessageCount, callOnCreation: false) {
            self.updateBadge()
        }
        
        observeLastMessageProperties()
        
        observeConversation(\.displayName, callOnCreation: false) {
            self.updateTitleLabel()
        }
        
        observeConversation(\.groupName, callOnCreation: false) {
            self.updateTitleLabel()
        }
        
        observeConversation(\.groupImage, callOnCreation: false) {
            self.loadAvatar()
        }
        
        observeContact(\.imageData, callOnCreation: false) {
            self.loadAvatar()
        }
        
        observeContact(\.contactImage, callOnCreation: false) {
            self.loadAvatar()
        }
    }
    
    private func observeLastMessageProperties() {
        if let lastMessage = conversation?.lastMessage as? BallotMessage {
            observeLastMessage(lastMessage, keyPath: \.ballot, callOnCreation: false) {
                self.updateLastMessagePreview()
            }
        }
        else if let lastMessage = conversation?.lastMessage as? FileMessageEntity {
            observeLastMessage(lastMessage, keyPath: \.mimeType, callOnCreation: false) {
                self.updateLastMessagePreview()
            }

            observeLastMessage(lastMessage, keyPath: \.caption, callOnCreation: false) {
                self.updateLastMessagePreview()
            }
        }

        if let conversation = conversation,
           conversation.isGroup() {
            return
        }

        if let lastMessage = conversation?.lastMessage {
            observeLastMessage(lastMessage, keyPath: \.userack, callOnCreation: false) {
                self.updateDisplayStateImage()
            }

            observeLastMessage(lastMessage, keyPath: \.read, callOnCreation: false) {
                self.updateDisplayStateImage()
            }

            observeLastMessage(lastMessage, keyPath: \.delivered, callOnCreation: false) {
                self.updateDisplayStateImage()
            }

            observeLastMessage(lastMessage, keyPath: \.sendFailed, callOnCreation: false) {
                self.updateDisplayStateImage()
            }

            observeLastMessage(lastMessage, keyPath: \.sent, callOnCreation: false) {
                self.updateDisplayStateImage()
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
    private func observeConversation<Value>(
        _ keyPath: KeyPath<Conversation, Value>,
        callOnCreation: Bool = true,
        changeHandler: @escaping () -> Void
    ) {
        
        guard let conversation = conversation else {
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
    private func observeLastMessage<Message: BaseMessage, Value>(
        _ lastMessage: Message,
        keyPath: KeyPath<Message, Value>,
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

    /// Helper to add observers to the `contact` property
    ///
    /// All observers are stored in the `observers` property.
    ///
    /// - Parameters:
    ///   - keyPath: Key path in `Contact` to observe
    ///   - callOnCreation: Should the handler be called during observer creation?
    ///   - changeHandler: Handler called on each observed change.
    ///                     Don't forget to capture `self` weakly! Dispatched on the main queue.
    private func observeContact<Value>(
        _ keyPath: KeyPath<ContactEntity, Value>,
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
    
    private func removeContactObservers() {
        // Invalidate all observers
        for observer in contactObservers {
            observer.invalidate()
        }
        
        // Remove them so we don't reference old observers
        contactObservers.removeAll()
    }
}

// MARK: - Reusable

extension ConversationTableViewCell: Reusable { }
