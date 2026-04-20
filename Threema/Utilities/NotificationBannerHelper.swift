import Foundation
import GroupCalls
import NotificationBannerSwift
import ThreemaFramework
import ThreemaMacros

@objc final class NotificationBannerHelper: NSObject {
    @objc class func newBanner(baseMessage: BaseMessageEntity) {
        DispatchQueue.main.async {
            // Reload CoreData object because of concurrency problem
            let businessInjector = BusinessInjector.ui
            let entityManager = businessInjector.entityManager
            
            guard let message = entityManager.entityFetcher
                .managedObject(with: baseMessage.objectID) as? PreviewableMessage else {
                return
            }

            let profileImageView = ProfilePictureImageView()
            var thumbnailImageView: UIImageView?
            
            var title = message.conversation.displayName
           
            if message.conversation.conversationCategory == .private {
                profileImageView.info = nil
            }
            else if message.conversation.isGroup {
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
            let bodyFont = UIFont.preferredFont(forTextStyle: .subheadline)
            
            if message.conversation.conversationCategory == .private {
                title = #localize("private_message_label")
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
                subtitleFont: bodyFont,
                subtitleColor: .label,
                leftView: profileImageView,
                rightView: thumbnailImageView,
                style: .info,
                colors: CustomBannerColors(),
                sideViewSize: 50.0
            )
            
            banner.transparency = 0.9
            banner.duration = 3.0
            banner.applyStyling(cornerRadius: 8)
            banner.subtitleLabel?.numberOfLines = 2
            
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
            
            if message.conversation.conversationCategory != .private {
                banner.subtitleLabel?.attributedText = message.previewAttributedText(
                    for: .notificationBanner,
                    settingsStore: businessInjector.settingsStore
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
        let bodyFont = UIFont.preferredFont(forTextStyle: .subheadline)
        
        let businessInjector = BusinessInjector.ui
        let profilePictureView = ProfilePictureImageView()
        let markupParser = MarkupParser()
        
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
            subtitleFont: bodyFont,
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
        
        let bodyAttributedString = markupParser.previewString(
            for: body,
            font: bodyFont
        )
        banner.subtitleLabel!.attributedText = bodyAttributedString
        
        banner.onTap = {
            banner.bannerQueue.dismissAllForced()
            // switch to selected conversation
            let entityManager = businessInjector.entityManager
            entityManager.performBlock {
                if let conversation = entityManager.entityFetcher.managedObject(with: conversationManagedObjectID) {
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
            NotificationBannerQueue.default.dismissAllForced()
        }
    }
    
    /// Dismiss and remove all the banners for the contact (Threema Identity of contact) or the identity of the group
    /// (GroupID as hex)
    /// - Parameter identifier: Threema ID or GroupID as hex
    @objc class func dismissAllNotifications(for identifier: String) {
        DispatchQueue.main.async {
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

final class CustomBannerColors: BannerColorsProtocol {
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
