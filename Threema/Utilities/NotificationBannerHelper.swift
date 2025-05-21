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

import Foundation
import GroupCalls
import MarqueeLabel
import SnapKit
import ThreemaFramework
import ThreemaMacros

@objc class NotificationBannerHelper: NSObject {
    @objc class func newBanner(baseMessage: BaseMessageEntity) {
        DispatchQueue.main.async {
            // Reload CoreData object because of concurrency problem
            let businessInjector = BusinessInjector.ui
            let entityManager = businessInjector.entityManager
            let message = entityManager.entityFetcher.getManagedObject(by: baseMessage.objectID) as! PreviewableMessage

            let profileImageView = ProfilePictureImageView()
            var thumbnailImageView: UIImageView?
            
            var title = message.conversation.displayName
            
            if message.conversation.isGroup {
                let group = businessInjector.groupManager.getGroup(conversation: baseMessage.conversation)
                profileImageView.info = .group(group)
            }
            else if let contact = message.conversation.contact {
                let businessContact = Contact(contactEntity: contact)
                profileImageView.info = .contact(businessContact)
            }
            else {
                profileImageView.info = .contact(nil)
            }
           
            if let imageMessageEntity = message as? ImageMessageEntity {
                if let thumbnail = imageMessageEntity.thumbnail {
                    thumbnailImageView = getThumbnail(for: thumbnail.uiImage())
                }
            }
            else if message is AudioMessageEntity {
                thumbnailImageView = getThumbnailAudio()
            }
            else if let fileMessageEntity = message as? FileMessageEntity {
                if fileMessageEntity.renderType == .voiceMessage {
                    thumbnailImageView = getThumbnailAudio()
                }
                else if let thumbnail = fileMessageEntity.thumbnail {
                    thumbnailImageView = getThumbnail(for: thumbnail.uiImage())
                    thumbnailImageView?.contentMode = .scaleAspectFit
                }
            }
            
            let titleFontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .headline)
            let bodyFontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .subheadline)
            
            var body = TextStyleUtils.makeMentionsString(forText: message.previewText)
            
            if message.isGroupMessage {
                // Quickfix: Sender should never be `nil` for an incoming group message
                if let sender = message.sender {
                    body = "\(sender.displayName): \(body ?? "")"
                }
            }
            
            if message.conversation.conversationCategory == .private {
                title = #localize("private_message_label")
                body = " "
                thumbnailImageView = nil
                
                if message.isGroupMessage {
                    profileImageView.info = .group(nil)
                }
                else {
                    profileImageView.info = .contact(nil)
                }
            }
            
            let banner = FloatingNotificationBanner(
                title: title,
                subtitle: "",
                titleFont: UIFont.boldSystemFont(ofSize: titleFontDescriptor.pointSize),
                titleColor: .label,
                subtitleFont: UIFont.systemFont(ofSize: bodyFontDescriptor.pointSize),
                subtitleColor: .label,
                leftView: profileImageView,
                rightView: thumbnailImageView,
                style: .info,
                colors: CustomBannerColors(),
                sideViewSize: 50.0
            )
            
            if let groupID = message.conversation.groupID {
                banner.identifier = groupID.hexEncodedString()
            }
            else {
                if let contact = message.conversation.contact {
                    banner.identifier = contact.identity
                }
            }
            
            banner.transparency = 0.9
            banner.duration = 3.0
            banner.applyStyling(cornerRadius: 8)
            banner.subtitleLabel?.numberOfLines = 2
            
            var formattedAttributeString: NSMutableAttributedString?
            if message.conversation.groupID != nil {
                var contactString = ""
                if !message.isKind(of: SystemMessageEntity.self) {
                    if let sender = message.sender {
                        contactString = "\(sender.displayName): "
                    }
                    else {
                        contactString = "\(#localize("me")): "
                    }
                }
                
                let attributed = TextStyleUtils.makeAttributedString(
                    from: message.previewText,
                    with: UIFont.systemFont(ofSize: bodyFontDescriptor.pointSize),
                    textColor: .label,
                    isOwn: true,
                    application: UIApplication.shared
                )
                let messageAttributedString = NSMutableAttributedString(
                    attributedString: banner.subtitleLabel!
                        .applyMarkup(for: attributed)
                )
                let attributedContact = TextStyleUtils.makeAttributedString(
                    from: contactString,
                    with: UIFont.systemFont(ofSize: bodyFontDescriptor.pointSize),
                    textColor: .label,
                    isOwn: true,
                    application: UIApplication.shared
                )
                formattedAttributeString = NSMutableAttributedString(attributedString: attributedContact!)
                formattedAttributeString?.append(messageAttributedString)
            }
            else {
                let attributed = TextStyleUtils.makeAttributedString(
                    from: message.previewText,
                    with: UIFont.systemFont(ofSize: bodyFontDescriptor.pointSize),
                    textColor: .label,
                    isOwn: true,
                    application: UIApplication.shared
                )
                formattedAttributeString = NSMutableAttributedString(
                    attributedString: banner.subtitleLabel!
                        .applyMarkup(for: attributed)
                )
            }
            
            if message.conversation.conversationCategory == .private {
                banner.subtitleLabel?.setText(nil)
            }
            else {
                banner.subtitleLabel!.attributedText = TextStyleUtils.makeMentionsAttributedString(
                    for: formattedAttributeString,
                    textFont: banner.subtitleLabel!.font,
                    at: .secondaryLabel.withAlphaComponent(0.6),
                    messageInfo: 2,
                    application: UIApplication.shared
                )
            }
            banner.onTap = {
                banner.bannerQueue.dismissAllForced()
                // Switch to selected conversation
                NotificationCenter.default.post(
                    name: NSNotification.Name(rawValue: kNotificationShowConversation),
                    object: nil,
                    userInfo: [kKeyConversation: message.conversation]
                )
            }
            
            banner.onSwipeUp = {
                banner.bannerQueue.removeAll()
            }
            let shadowEdgeInsets = UIEdgeInsets(top: 8, left: 2, bottom: 0, right: 2)
            if Colors.theme == .dark {
                banner.show(
                    shadowColor: Colors.shadowNotification,
                    shadowOpacity: 0.5,
                    shadowBlurRadius: 7,
                    shadowEdgeInsets: shadowEdgeInsets
                )
            }
            else {
                banner.show(
                    shadowColor: Colors.shadowNotification,
                    shadowOpacity: 1.0,
                    shadowBlurRadius: 10,
                    shadowEdgeInsets: shadowEdgeInsets
                )
            }
        }
    }

    private class func getThumbnailAudio() -> UIImageView? {
        let image = UIImage(
            systemName: "mic.fill",
            withConfiguration: UIImage.SymbolConfiguration(textStyle: .body)
        )?
            .withTintColor(.label, renderingMode: .alwaysOriginal)
        return getThumbnail(for: image, contentMode: .center)
    }

    private class func getThumbnail(
        for image: UIImage?,
        contentMode: UIView.ContentMode = .scaleAspectFill
    ) -> UIImageView? {
        let thumbnailImageView = UIImageView(image: image)
        thumbnailImageView.contentMode = contentMode
        return thumbnailImageView
    }

    class func newBannerForStartGroupCall(
        conversationManagedObjectID: NSManagedObjectID,
        title: String,
        body: String,
        identifier: String
    ) {
        let titleFontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .headline)
        let bodyFontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .subheadline)
        
        let businessInjector = BusinessInjector.ui
        let profilePictureView = ProfilePictureImageView()
        
        if let conversation = businessInjector.entityManager.entityFetcher
            .existingObject(with: conversationManagedObjectID) as? ConversationEntity,
            conversation.conversationCategory != .private,
            let group = businessInjector.groupManager.getGroup(conversation: conversation) {
            profilePictureView.info = .group(group)
        }
        else {
            profilePictureView.info = .group(nil)
        }
        
        let banner = FloatingNotificationBanner(
            title: title,
            subtitle: body,
            titleFont: UIFont.boldSystemFont(ofSize: titleFontDescriptor.pointSize),
            titleColor: .label,
            subtitleFont: UIFont.preferredFont(forTextStyle: .title1),
            subtitleColor: .label,
            leftView: profilePictureView,
            rightView: nil,
            style: .info,
            colors: CustomBannerColors(),
            sideViewSize: 50.0
        )
        
        banner.identifier = identifier
        banner.transparency = 0.9
        banner.duration = 3.0
        banner.applyStyling(cornerRadius: 8)
        banner.subtitleLabel?.numberOfLines = 2
        
        let attributed = TextStyleUtils.makeAttributedString(
            from: body,
            with: UIFont.systemFont(ofSize: bodyFontDescriptor.pointSize),
            textColor: .label,
            isOwn: true,
            application: UIApplication.shared
        )
        let bodyAttributedString = NSMutableAttributedString(
            attributedString: banner.subtitleLabel!
                .applyMarkup(for: attributed)
        )
        
        banner.subtitleLabel!.attributedText = bodyAttributedString
        
        banner.onTap = {
            banner.bannerQueue.dismissAllForced()
            // switch to selected conversation
            let entityManager = businessInjector.entityManager
            entityManager.performBlock {
                if let conversation = entityManager.entityFetcher.getManagedObject(by: conversationManagedObjectID) {
                    NotificationCenter.default.post(
                        name: NSNotification.Name(rawValue: kNotificationShowConversation),
                        object: nil,
                        userInfo: [kKeyConversation: conversation]
                    )
                }
            }
        }
        
        banner.onSwipeUp = {
            banner.bannerQueue.removeAll()
        }
        let shadowEdgeInsets = UIEdgeInsets(top: 8, left: 2, bottom: 0, right: 2)
        if Colors.theme == .dark {
            banner.show(
                shadowColor: Colors.shadowNotification,
                shadowOpacity: 0.5,
                shadowBlurRadius: 7,
                shadowEdgeInsets: shadowEdgeInsets
            )
        }
        else {
            banner.show(
                shadowColor: Colors.shadowNotification,
                shadowOpacity: 1.0,
                shadowBlurRadius: 10,
                shadowEdgeInsets: shadowEdgeInsets
            )
        }
    }
        
    @objc class func dismissAllNotifications() {
        DispatchQueue.main.async {
            NotificationBannerQueue.default.removeAll()
        }
    }
    
    @objc class func dismissAllNotifications(for conversation: ConversationEntity) {
        DispatchQueue.main.async {
            var identifier: String?
            if let groupID = conversation.groupID {
                identifier = groupID.hexEncodedString()
            }
            else if let contact = conversation.contact {
                identifier = contact.identity
            }
            else {
                return
            }
            let banners = NotificationBannerQueue.default.banners
            for banner in banners {
                if banner.identifier == identifier {
                    if banner.isDisplaying == true {
                        banner.dismiss()
                    }
                    NotificationBannerQueue.default.removeBanner(banner)
                }
            }
        }
    }
}

class CustomBannerColors: BannerColorsProtocol {
    func color(for style: BannerStyle) -> UIColor {
        switch style {
        case .danger: .systemRed
        case .info: Colors.backgroundNotification
        case .customView: Colors.backgroundNotification
        case .success: .systemGreen
        case .warning: .systemOrange
        }
    }
}
