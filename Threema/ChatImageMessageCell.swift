//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2022 Threema GmbH
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
import CocoaLumberjackSwift

@objc open class ChatImageMessageCell: ChatBlobTextMessageCell{
    override open var message: BaseMessage! {
        didSet {
            setBaseMessage(newMessage: message)
        }
    }
    
    private var _imageView: UIImageView?
    private var _imageIcon: UIImageView?
    
    @objc override public init!(style: UITableViewCell.CellStyle, reuseIdentifier: String!, transparent: Bool) {
        super.init(style: style, reuseIdentifier: reuseIdentifier, transparent: transparent)
        
        _imageView = UIImageView.init()
        _imageView?.clearsContextBeforeDrawing = false
        _imageView?.contentMode = .scaleAspectFit
                
        contentView.addSubview(_imageView!)
        
        _imageIcon = UIImageView.init()
        _imageIcon?.clearsContextBeforeDrawing = false
        contentView.addSubview(_imageIcon!)
        
        _captionLabel = ChatTextMessageCell.makeAttributedLabel(withFrame: self.bounds)
        _captionLabel?.tapDelegate = self
        _captionLabel?.longPressDelegate = self
        contentView.addSubview(_captionLabel!)
        
        if #available(iOS 11.0, *) {
            _imageView?.accessibilityIgnoresInvertColors = true
        }
        
        setupColors()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension ChatImageMessageCell {
    // MARK: Override functions
    
    @objc override open class func height(for message: BaseMessage!, forTableWidth tableWidth: CGFloat) -> CGFloat {
        let imageMessage = message as! ImageMessage
        
        var cellHeight: CGFloat = 40.0
        let imageInsets = UIEdgeInsets.init(top: 5, left: 5, bottom: 5, right: 5)
        var scaledSize = CGSize.init()
        if imageMessage.thumbnail != nil {
            if imageMessage.thumbnail.data != nil && imageMessage.thumbnail.height.floatValue > 0 {
                let width: CGFloat = CGFloat(imageMessage.thumbnail.width.floatValue)
                let height: CGFloat = CGFloat(imageMessage.thumbnail.height.floatValue)
                let size: CGSize = CGSize.init(width: width, height: height)
                scaledSize = ChatImageMessageCell.scaleImageSize(toCell: size, forTableWidth: tableWidth)
                if scaledSize.height != scaledSize.height || scaledSize.height < 0 {
                    scaledSize.height = 40.0
                }
                cellHeight = scaledSize.height - 17.0
            }
        }
        
        if let image = imageMessage.image, let caption = image.getCaption(), caption.count > 0 {
            let x: CGFloat = 30.0
            
            let maxSize = CGSize.init(width: scaledSize.width - x, height: CGFloat.greatestFiniteMagnitude)
            var textSize: CGSize?
            let captionTextNSString = NSString.init(string: caption)
            
            if UserSettings.shared().disableBigEmojis && captionTextNSString.isOnlyEmojisMaxCount(3) {
                var dummyLabelEmoji: ZSWTappableLabel? = nil
                if dummyLabelEmoji == nil {
                    dummyLabelEmoji = ChatTextMessageCell.makeAttributedLabel(withFrame: CGRect.init(x: (x/2), y: 0.0, width: maxSize.width, height: maxSize.height))
                }
                dummyLabelEmoji!.font = ChatTextMessageCell.emojiFont()
                dummyLabelEmoji?.attributedText = NSAttributedString.init(string: caption, attributes: [NSAttributedString.Key.font: ChatMessageCell.emojiFont()!])
                textSize = dummyLabelEmoji?.sizeThatFits(maxSize)
                textSize!.height = textSize!.height + 23.0
            } else {
                var dummyLabel: ZSWTappableLabel? = nil
                if dummyLabel == nil {
                    dummyLabel = ChatTextMessageCell.makeAttributedLabel(withFrame: CGRect.init(x: (x/2), y: 0.0, width: maxSize.width, height: maxSize.height))
                }
                dummyLabel!.font = ChatTextMessageCell.textFont()
                let attributed = TextStyleUtils.makeAttributedString(from: caption, with: dummyLabel!.font, textColor: Colors.fontNormal(), isOwn: true, application: UIApplication.shared)
                let formattedAttributeString = NSMutableAttributedString.init(attributedString: (dummyLabel!.applyMarkup(for: attributed))!)
                dummyLabel?.attributedText = TextStyleUtils.makeMentionsAttributedString(for: formattedAttributeString, textFont: dummyLabel!.font!, at: dummyLabel!.textColor.withAlphaComponent(0.4), messageInfo: Int32(message.isOwn!.intValue), application: UIApplication.shared)
                textSize = dummyLabel?.sizeThatFits(maxSize)
                textSize!.height = textSize!.height + 23.0
            }
            cellHeight = cellHeight + textSize!.height
        } else {
            cellHeight += imageInsets.top + imageInsets.bottom
        }
        
        return cellHeight
    }
        
    override public func layoutSubviews() {
        let imageMessage = message as! ImageMessage
        
        var textSize: CGSize = CGSize.init(width: 0.0, height: 0.0)
        var size = CGSize.init(width: 80.0, height: 40.0)
        let x: CGFloat = 30.0
        let imageInsets = UIEdgeInsets.init(top: 5, left: 5, bottom: 5, right: 5)
        if imageMessage.thumbnail != nil {
            if imageMessage.thumbnail.data != nil && imageMessage.thumbnail.height.floatValue > 0 {
                let width: CGFloat = CGFloat(imageMessage.thumbnail.width.floatValue)
                let height: CGFloat = CGFloat(imageMessage.thumbnail.height.floatValue)
                let imageMessageSize: CGSize = CGSize.init(width: width, height: height)
                size = ChatFileImageMessageCell.scaleImageSize(toCell: imageMessageSize, forTableWidth: frame.size.width)
                
                if let image = imageMessage.image, let caption = image.getCaption(), caption.count > 0 {
                    textSize = _captionLabel!.sizeThatFits(CGSize.init(width: size.width - x, height: CGFloat.greatestFiniteMagnitude))
                    textSize.height = textSize.height + 12.0
                }
                
                
                let bubbleSize = CGSize.init(width: size.width + imageInsets.left + imageInsets.right, height: size.height + imageInsets.top + imageInsets.bottom + textSize.height)
                setBubble(bubbleSize)
            } else {
                if let image = imageMessage.image, let caption = image.getCaption(), caption.count > 0 {
                    textSize = _captionLabel!.sizeThatFits(CGSize.init(width: size.width - x, height: CGFloat.greatestFiniteMagnitude))
                    textSize.height = textSize.height + 12.0
                }
                setBubbleContentSize(CGSize.init(width: size.width, height: size.height + textSize.height))
            }
        } else {
           setBubbleContentSize(CGSize.init(width: size.width, height: size.height + textSize.height))
        }
        
        super.layoutSubviews()
        
        _imageView?.frame = CGRect.init(x: msgBackground.frame.origin.x + imageInsets.left, y: msgBackground.frame.origin.y + imageInsets.top, width: size.width, height: size.height)
        var originX = msgBackground.frame.origin.x + (x/2)
        if _captionLabel?.textAlignment == .right {
            originX = msgBackground.frame.origin.x + msgBackground.frame.size.width - (x/2) - textSize.width
        }
        _captionLabel!.frame  = CGRect.init(x:ceil(originX), y: ceil(_imageView!.frame.origin.y + _imageView!.frame.size.height), width: ceil(textSize.width), height: ceil(textSize.height))
        
        let mask: CALayer = bubbleMaskWithoutArrow(forImageSize: CGSize.init(width: _imageView!.frame.size.width, height: _imageView!.frame.size.height))
        _imageView?.layer.mask = mask
        _imageView?.layer.masksToBounds = true

        if message.isOwn != nil, message.isOwn.boolValue {
            progressBar.frame = CGRect.init(x: _imageView!.frame.origin.x + 16.0, y: _imageView!.frame.origin.y + _imageView!.frame.size.height - 24.0, width: size.width - 32.0, height: 16.0)
            resendButton.frame = CGRect.init(x: _imageView!.frame.origin.x - kMessageScreenMargin, y: _imageView!.frame.origin.y + (_imageView!.frame.size.height - 32.0) / 2, width: 114.0, height: 32.0)
        } else {            
            if imageMessage.thumbnail == nil {
                activityIndicator.frame = CGRect.init(x: 72.0 + contentLeftOffset(), y: 17.0, width: 21.0, height: 21.0)
                _imageIcon!.frame = CGRect.init(x: 26.0 + contentLeftOffset(), y: 19.0, width: 24.0, height: 18.0)
            } else {
                if imageMessage.thumbnail.data == nil {
                    activityIndicator.frame = CGRect.init(x: 72.0 + contentLeftOffset(), y: 17.0, width: 21.0, height: 21.0)
                    _imageIcon!.frame = CGRect.init(x: 26.0 + contentLeftOffset(), y: 19.0, width: 24.0, height: 18.0)
                }
            }
        }
    }
    
    override open func accessibilityLabelForContent() -> String! {
        if _captionLabel?.text != nil {
            return "\(BundleUtil.localizedString(forKey: "image")). \(_captionLabel!.text!))"
        } else {
            return BundleUtil.localizedString(forKey: "image")
        }
    }
    
    override open func showActivityIndicator() -> Bool {
        return showProgressBar() == false
    }
    
    override open func showProgressBar() -> Bool {
        if message != nil {
            if message.isOwn != nil {
                return message.isOwn.boolValue
            }
        }
        return false
    }
    
    override open func messageTapped(_ sender: Any!) {
        let imageMessage = message as! ImageMessage
        if imageMessage.image == nil {
            // Not loaded yet. Should we start loading again?
            if imageMessage.progress == nil {
                let loader: BlobMessageLoader = BlobMessageLoader.init()
                loader.start(with: imageMessage, onCompletion: { (baseMessage) in
                    DDLogInfo("File image message blob load completed")
                }) { (error) in
                    DDLogInfo("File image message blob load failed with error: \(error!)")
                }
            }
        }
        chatVc.imageMessageTapped(imageMessage)
    }
    
    override open func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        let imageMessage = message as! ImageMessage
        let mdmSetup = MDMSetup.init(setup: false)
        if action == #selector(resendMessage(_:)) && imageMessage.isOwn.boolValue && imageMessage.sendFailed.boolValue {
            return true
        }
        else if action == #selector(deleteMessage(_:)) && imageMessage.isOwn.boolValue && imageMessage.progress != nil {
            /* don't allow messages in progress to be deleted */
            return false
        }
        else if action == #selector(shareMessage(_:)) {
            if #available(iOS 13.0, *) {
                let mdmSetup = MDMSetup.init(setup: false)
                if mdmSetup?.disableShareMedia() == true {
                    return false;
                }
            }
            return imageMessage.image != nil
        }
        else if action == #selector(forwardMessage(_:)) {
            if #available(iOS 13.0, *) {
                return imageMessage.image != nil
            } else {
                return false;
            }
        }
        else if action == #selector(copyMessage(_:)) && mdmSetup?.disableShareMedia() == true {
            return false
        }
        else if action == #selector(speakMessage(_:)) && _captionLabel?.text != nil {
            return true
        }
        else {
            return super.canPerformAction(action, withSender: sender)
        }
    }
    
    @objc override open func copyMessage(_ menuController: UIMenuController!) {
        let imageMessage = message as! ImageMessage
        if let image = imageMessage.image, let caption = image.getCaption(), caption.count > 0 {
            UIPasteboard.general.string = caption
        } else {
            if imageMessage.image != nil, imageMessage.image.data != nil {
                UIPasteboard.general.image = imageMessage.image.uiImage
            } else {
                if imageMessage.thumbnail != nil, imageMessage.thumbnail.data != nil {
                    UIPasteboard.general.image = imageMessage.thumbnail.uiImage
                }
            }
        }
    }
    
    open override func textForQuote() -> String! {
        return (_captionLabel?.text as? String ?? "")
    }
        
    open override func performPlayActionForAccessibility() -> Bool {
        messageTapped(self)
        return true
    }
    
    open override func shouldHideBubbleBackground() -> Bool {
        return false
    }
    
    open override func previewViewController() -> UIViewController! {
        return chatVc.headerView.getPhotoBrowser(at: message, forPeeking: true)
    }
    
    open override func previewViewController(for previewingContext: UIViewControllerPreviewing!, viewControllerForLocation location: CGPoint) -> UIViewController! {
        if let controller = super.previewViewController(for: previewingContext, viewControllerForLocation: location) {
            return controller
        }
        return chatVc.headerView.getPhotoBrowser(at: message, forPeeking: true)
    }
    
    open override func setupColors() {
        super.setupColors()
        _captionLabel?.textColor = Colors.fontNormal()
    }
    
    @available(iOS 13.0, *)
    open override func getContextMenu(_ indexPath: IndexPath!, point: CGPoint) -> UIContextMenuConfiguration! {
        if self.isEditing == true {
            return nil
        }
    
        // returns nil if there is no link tapped
        if let menu = contextMenuForLink(indexPath, point: point) {
            return menu
        }
        
        if let mdmSetup = MDMSetup.init(setup: false),
           !mdmSetup.disableShareMedia(),
           let imageMessage = message as? ImageMessage,
           let imageMessageImage = imageMessage.image,
           imageMessageImage.data != nil
        {
            let conf = UIContextMenuConfiguration.init(identifier: indexPath as NSIndexPath, previewProvider: { () -> UIViewController? in
                return self.previewViewController()
            }) { (suggestedActions) -> UIMenu? in
                var menuItems = super.contextMenuItems()!
                let saveImage = UIImage.init(systemName: "square.and.arrow.down.fill", compatibleWith: self.traitCollection)
                let saveAction = UIAction.init(title: BundleUtil.localizedString(forKey: "save"), image: saveImage, identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off) { (action) in
                    if let image = imageMessage.image, let uiImage = image.uiImage {
                        AlbumManager.shared.save(image: uiImage)
                    } else {
                        DDLogError("Could not save image because image or image.uiImage was nil")
                    }
                    
                }
                
                if self.message.isOwn.boolValue == true || self.chatVc.conversation.isGroup() == true {
                    menuItems.insert(saveAction, at: 0)
                } else {
                    menuItems.insert(saveAction, at: 1)
                }
                return UIMenu.init(title: "", image: nil, identifier: nil, options: .displayInline, children: menuItems as! [UIMenuElement])
            }
            return conf
        }
        
        return super.getContextMenu(indexPath, point: point)
    }
}

extension ChatImageMessageCell {
    // MARK: Public functions
    
    func setBaseMessage(newMessage: BaseMessage) {
        let imageMessage = newMessage as! ImageMessage
        
        super.message = newMessage
        
        if let thumb = imageMessage.thumbnail {
            if let data = thumb.data {
              _imageView?.image = UIImage.init(data: data)
            }
        }
        var size = CGSize.init(width: 80.0, height: 40.0)
        
        if imageMessage.thumbnail != nil {
            if imageMessage.thumbnail.data != nil && imageMessage.thumbnail.height.floatValue > 0 {
                let width: CGFloat = CGFloat(imageMessage.thumbnail.width.floatValue)
                let height: CGFloat = CGFloat(imageMessage.thumbnail.height.floatValue)
                let imageMessageSize: CGSize = CGSize.init(width: width, height: height)
                size = ChatImageMessageCell.scaleImageSize(toCell: imageMessageSize, forTableWidth: frame.size.width)
            }
            
            _imageView?.frame.size = size
        }
        
        if imageMessage.isOwn != nil, imageMessage.isOwn.boolValue {
            _imageView?.autoresizingMask = .flexibleLeftMargin
            _imageView?.isHidden = false
            _imageIcon?.isHidden = true
        } else {
            if imageMessage.thumbnail != nil{
                if imageMessage.thumbnail.data != nil {
                    _imageView?.autoresizingMask = .flexibleLeftMargin
                    _imageView?.isHidden = false
                    _imageIcon?.isHidden = true
                } else {
                    _imageView?.isHidden = true
                    let image = BundleUtil.imageNamed("Landscape")
                    _imageIcon!.image = image!.withTint(Colors.fontLight())
                    _imageIcon?.alpha = 0.7
                    _imageIcon?.isHidden = false
                }
            } else {
                _imageView?.isHidden = true
                let image = BundleUtil.imageNamed("Landscape")
                _imageIcon!.image = image!.withTint(Colors.fontLight())
                _imageIcon?.alpha = 0.7
                _imageIcon?.isHidden = false
            }
        }
        
        if let image = imageMessage.image, let captionText = image.getCaption(), captionText.count > 0 {
            _captionLabel?.font = ChatMessageCell.textFont()
            let attributed = TextStyleUtils.makeAttributedString(from: captionText, with: _captionLabel!.font, textColor: Colors.fontNormal(), isOwn: true, application: UIApplication.shared)
            let formattedAttributeString = NSMutableAttributedString.init(attributedString: (_captionLabel!.applyMarkup(for: attributed))!)
            _captionLabel?.attributedText = TextStyleUtils.makeMentionsAttributedString(for: formattedAttributeString, textFont: _captionLabel!.font!, at: _captionLabel!.textColor.withAlphaComponent(0.4), messageInfo: Int32(message.isOwn!.intValue), application: UIApplication.shared)
            _captionLabel?.textAlignment = captionText.textAlignment()
            _captionLabel?.isHidden = false
        }
        else {
            _captionLabel?.text = nil
            _captionLabel?.isHidden = true
        }
        
        setupColors()
        self.setNeedsLayout()
    }
    
    @objc func resendMessage(_ menuController: UIMenuController) {
        DDLogError("ImageMessages can not be resent anymore.")
    }
}
