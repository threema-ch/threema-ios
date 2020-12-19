//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020 Threema GmbH
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
import SnapKit
import MarqueeLabel

@objc class NotificationBannerHelper: NSObject {
    @objc class func newBanner(message: BaseMessage) {
        DispatchQueue.main.async {
            var contactImageView: UIImageView?
            var thumbnailImageView: UIImageView?
            
            if let contactImage = AvatarMaker.shared()?.avatar(for: message.conversation, size: 56.0, masked: true) {
                contactImageView = UIImageView.init(image: contactImage)
            }
            
            if message.isKind(of: ImageMessage.self) {
                let imageMessage = message as! ImageMessage
                if let thumbnail = imageMessage.thumbnail {
                    thumbnailImageView = UIImageView.init(image: thumbnail.uiImage)
                    thumbnailImageView?.contentMode = .scaleAspectFit
                }
            }
            else if message.isKind(of: FileMessage.self) {
                let fileMessage = message as! FileMessage
                if let thumbnail = fileMessage.thumbnail {
                    thumbnailImageView = UIImageView.init(image: thumbnail.uiImage)
                    thumbnailImageView?.contentMode = .scaleAspectFit
                }
            }
            else if message.isKind(of: AudioMessage.self) {
                let thumbnail = BundleUtil.imageNamed("ActionMicrophone")?.withTint(Colors.fontNormal())
                thumbnailImageView = UIImageView.init(image: thumbnail)
                thumbnailImageView?.contentMode = .center
            }
            
            let titleFontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .headline)
            let bodyFontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .subheadline)
            
            var body = message.previewText()
            body = TextStyleUtils.makeMentionsString(forText: body)
            
            if message.conversation.groupId != nil {
                body = "\(message.sender.displayName ?? ""): \(body ?? "")"
            }
            
            let banner = FloatingNotificationBanner.init(title: message.conversation.displayName, subtitle: "", titleFont: UIFont.boldSystemFont(ofSize: titleFontDescriptor.pointSize), titleColor: Colors.fontNormal(), subtitleFont: UIFont.systemFont(ofSize: bodyFontDescriptor.pointSize), subtitleColor: Colors.fontNormal(), leftView: contactImageView, rightView: thumbnailImageView, style: .info, colors: CustomBannerColors(), sideViewSize: 50.0)
            
            if message.conversation.groupId != nil {
                banner.identifier = message.conversation.groupId.hexEncodedString()
            } else {
                banner.identifier = message.conversation.contact.identity
            }
            
            banner.transparency = 0.9
            banner.duration = 3.0
            banner.applyStyling(cornerRadius: 8)
            banner.subtitleLabel?.numberOfLines = 2
            
            var formattedAttributeString: NSMutableAttributedString?
            if message.conversation.groupId != nil {
                var contactString = ""
                if !message.isKind(of: SystemMessage.self) {
                    if message.sender == nil {
                        contactString = String.init(format: "%@: ", BundleUtil.localizedString(forKey: "me"))
                    } else {
                        contactString = String.init(format: "%@: ", message.sender.displayName)
                    }
                }
                
                let attributed = TextStyleUtils.makeAttributedString(from: message.previewText(), with: UIFont.systemFont(ofSize: bodyFontDescriptor.pointSize), textColor: Colors.fontNormal(), isOwn: true, application: UIApplication.shared)
                let messageAttributedString = NSMutableAttributedString.init(attributedString: banner.subtitleLabel!.applyMarkup(for: attributed))
                let attributedContact = TextStyleUtils.makeAttributedString(from: contactString, with: UIFont.systemFont(ofSize: bodyFontDescriptor.pointSize), textColor: Colors.fontNormal(), isOwn: true, application: UIApplication.shared)
                formattedAttributeString = NSMutableAttributedString.init(attributedString: attributedContact!)
                formattedAttributeString?.append(messageAttributedString)
            } else {
                let attributed = TextStyleUtils.makeAttributedString(from:message.previewText(), with: UIFont.systemFont(ofSize: bodyFontDescriptor.pointSize), textColor: Colors.fontNormal(), isOwn: true, application: UIApplication.shared)
                formattedAttributeString = NSMutableAttributedString.init(attributedString: banner.subtitleLabel!.applyMarkup(for: attributed))
            }
            
            banner.subtitleLabel!.attributedText = TextStyleUtils.makeMentionsAttributedString(for: formattedAttributeString, textFont: banner.subtitleLabel!.font, at: Colors.fontLight()?.withAlphaComponent(0.6), messageInfo: 2, application: UIApplication.shared)
            
            banner.onTap = {
                banner.bannerQueue.dismissAllForced()
                /* switch to selected conversation */
                if  let conversation = message.conversation {
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: kNotificationShowConversation), object: nil, userInfo: [kKeyConversation: conversation])
                }
            }
            
            banner.onSwipeUp = {
                banner.bannerQueue.removeAll()
            }
            let shadowEdgeInsets = UIEdgeInsets(top: 8, left: 2, bottom: 0, right: 2)
            if Colors.getTheme() == ColorThemeDark || Colors.getTheme() == ColorThemeDarkWork {
                banner.show( shadowColor: Colors.notificationShadow(), shadowOpacity: 0.5, shadowBlurRadius: 7, shadowEdgeInsets: shadowEdgeInsets)
            } else {
                banner.show(shadowColor: Colors.notificationShadow(), shadowOpacity: 1.0, shadowBlurRadius: 10, shadowEdgeInsets: shadowEdgeInsets)
            }
        }
    }
        
    @objc class func dismissAllNotifications() {
        DispatchQueue.main.async {
            NotificationBannerQueue.default.removeAll()
        }
    }
    
    @objc class func dismissAllNotifications(for conversation:Conversation) {
        DispatchQueue.main.async {
            var identifier: String?
            if let groupId = conversation.groupId {
                identifier = groupId.hexEncodedString()
            }
            else if let contact = conversation.contact {
                identifier = contact.identity
            } else {
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
    
    @objc class func newInfoToast(title: String, body: String) {
        newToast(title: title, body: body, bannerStyle: .warning)
    }
    
    @objc class func newErrorToast(title: String, body: String) {
        newToast(title: title, body: body, bannerStyle: .danger)
    }
    
    private class func newToast(title: String, body: String, bannerStyle: BannerStyle) {
        DispatchQueue.main.async {
            let titleFontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .headline)
            let bodyFontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .subheadline)
            
            let banner = FloatingNotificationBanner.init(title: title, subtitle: body, titleFont: UIFont.boldSystemFont(ofSize: titleFontDescriptor.pointSize), titleColor: Colors.fontNormal(), subtitleFont: UIFont.systemFont(ofSize: bodyFontDescriptor.pointSize), subtitleColor: Colors.white(), leftView: UIImageView.init(image: BundleUtil.imageNamed("InfoFilled")), rightView: nil, style: bannerStyle, colors: CustomBannerColors())
            
            banner.titleLabel!.attributedText = NSAttributedString.init(string: title, attributes: [NSAttributedString.Key.foregroundColor: Colors.white() as Any, NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: titleFontDescriptor.pointSize) as Any])
            banner.subtitleLabel!.attributedText = NSAttributedString.init(string: body, attributes: [NSAttributedString.Key.foregroundColor: Colors.white() as Any, NSAttributedString.Key.font: UIFont.systemFont(ofSize: bodyFontDescriptor.pointSize) as Any])
            
            banner.transparency = 1.0
            banner.duration = 5.0
            banner.subtitleLabel?.numberOfLines = 0
            
            banner.show()
        }
    }
}

class CustomBannerColors: BannerColorsProtocol {
    internal func color(for style: BannerStyle) -> UIColor {
        switch style {
        case .danger:    return Colors.red()
        case .info:        return Colors.notificationBackground()
        case .customView:    return Colors.notificationBackground()
        case .success:    return Colors.green()
        case .warning:    return Colors.orange()
        }
    }

}
