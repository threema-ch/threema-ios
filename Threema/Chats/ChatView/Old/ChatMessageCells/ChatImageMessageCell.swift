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

import CocoaLumberjackSwift
import Foundation

@objc open class ChatImageMessageCell: ChatBlobTextMessageCell {
    override open var message: BaseMessage! {
        didSet {
            setBaseMessage(newMessage: message)
        }
    }
    
    private var _imageView: UIImageView?
    private var _imageIcon: UIImageView?
    
    @objc override public init!(style: UITableViewCell.CellStyle, reuseIdentifier: String!, transparent: Bool) {
        super.init(style: style, reuseIdentifier: reuseIdentifier, transparent: transparent)
        
        self._imageView = UIImageView()
        _imageView?.clearsContextBeforeDrawing = false
        _imageView?.contentMode = .scaleAspectFit
                
        contentView.addSubview(_imageView!)
        
        self._imageIcon = UIImageView()
        _imageIcon?.clearsContextBeforeDrawing = false
        contentView.addSubview(_imageIcon!)
        
        _captionLabel = ChatTextMessageCell.makeAttributedLabel(withFrame: bounds)
        _captionLabel?.tapDelegate = self
        _captionLabel?.longPressDelegate = self
        contentView.addSubview(_captionLabel!)
        
        _imageView?.accessibilityIgnoresInvertColors = true
                
        updateColors()
    }
}

extension ChatImageMessageCell {
    // MARK: Override functions
    
    @objc override open class func height(for message: BaseMessage!, forTableWidth tableWidth: CGFloat) -> CGFloat {
        let imageMessageEntity = message as! ImageMessageEntity
        
        var cellHeight: CGFloat = 40.0
        let imageInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        var scaledSize = CGSize()
        if imageMessageEntity.thumbnail != nil {
            if imageMessageEntity.thumbnail.data != nil, imageMessageEntity.thumbnail.height.floatValue > 0 {
                let width = CGFloat(imageMessageEntity.thumbnail.width.floatValue)
                let height = CGFloat(imageMessageEntity.thumbnail.height.floatValue)
                let size = CGSize(width: width, height: height)
                scaledSize = ChatImageMessageCell.scaleImageSize(
                    toCell: size,
                    forTableWidth: tableWidth,
                    isGroup: imageMessageEntity.conversation.isGroup()
                )
                if scaledSize.height != scaledSize.height || scaledSize.height < 0 {
                    scaledSize.height = 40.0
                }
                cellHeight = scaledSize.height - 17.0
            }
        }
        
        if let image = imageMessageEntity.image, let caption = image.getCaption(), !caption.isEmpty {
            let x: CGFloat = 30.0
            
            let maxSize = CGSize(width: scaledSize.width - x, height: CGFloat.greatestFiniteMagnitude)
            var textSize: CGSize?
            let captionTextNSString = NSString(string: caption)
            
            if UserSettings.shared().disableBigEmojis, captionTextNSString.isOnlyEmojisMaxCount(3) {
                var dummyLabelEmoji: ZSWTappableLabel?
                if dummyLabelEmoji == nil {
                    dummyLabelEmoji = ChatTextMessageCell
                        .makeAttributedLabel(withFrame: CGRect(
                            x: x / 2,
                            y: 0.0,
                            width: maxSize.width,
                            height: maxSize.height
                        ))
                }
                dummyLabelEmoji!.font = ChatTextMessageCell.emojiFont()
                dummyLabelEmoji?.attributedText = NSAttributedString(
                    string: caption,
                    attributes: [NSAttributedString.Key.font: ChatMessageCell.emojiFont()!]
                )
                textSize = dummyLabelEmoji?.sizeThatFits(maxSize)
                textSize!.height = textSize!.height + 23.0
            }
            else {
                var dummyLabel: ZSWTappableLabel?
                if dummyLabel == nil {
                    dummyLabel = ChatTextMessageCell
                        .makeAttributedLabel(withFrame: CGRect(
                            x: x / 2,
                            y: 0.0,
                            width: maxSize.width,
                            height: maxSize.height
                        ))
                }
                dummyLabel!.font = ChatTextMessageCell.textFont()
                let attributed = TextStyleUtils.makeAttributedString(
                    from: caption,
                    with: dummyLabel!.font,
                    textColor: Colors.text,
                    isOwn: true,
                    application: UIApplication.shared
                )
                let formattedAttributeString =
                    NSMutableAttributedString(attributedString: (dummyLabel!.applyMarkup(for: attributed))!)
                dummyLabel?.attributedText = TextStyleUtils.makeMentionsAttributedString(
                    for: formattedAttributeString,
                    textFont: dummyLabel!.font!,
                    at: dummyLabel!.textColor.withAlphaComponent(0.4),
                    messageInfo: Int32(message.isOwn!.intValue),
                    application: UIApplication.shared
                )
                textSize = dummyLabel?.sizeThatFits(maxSize)
                textSize!.height = textSize!.height + 23.0
            }
            cellHeight = cellHeight + textSize!.height
        }
        else {
            cellHeight += imageInsets.top + imageInsets.bottom
        }
        
        return cellHeight
    }
        
    override public func layoutSubviews() {
        let imageMessageEntity = message as! ImageMessageEntity
        
        var textSize = CGSize(width: 0.0, height: 0.0)
        var size = CGSize(width: 80.0, height: 40.0)
        let x: CGFloat = 30.0
        let imageInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        if imageMessageEntity.thumbnail != nil {
            if imageMessageEntity.thumbnail.data != nil, imageMessageEntity.thumbnail.height.floatValue > 0 {
                let width = CGFloat(imageMessageEntity.thumbnail.width.floatValue)
                let height = CGFloat(imageMessageEntity.thumbnail.height.floatValue)
                let imageMessageSize = CGSize(width: width, height: height)
                size = ChatFileImageMessageCell.scaleImageSize(
                    toCell: imageMessageSize,
                    forTableWidth: frame.size.width,
                    isGroup: imageMessageEntity.conversation.isGroup()
                )
                
                if let image = imageMessageEntity.image, let caption = image.getCaption(), !caption.isEmpty {
                    textSize = _captionLabel!
                        .sizeThatFits(CGSize(width: size.width - x, height: CGFloat.greatestFiniteMagnitude))
                    textSize.height = textSize.height + 12.0
                }
                
                let bubbleSize = CGSize(
                    width: size.width + imageInsets.left + imageInsets.right,
                    height: size.height + imageInsets.top + imageInsets.bottom + textSize.height
                )
                setBubble(bubbleSize)
            }
            else {
                if let image = imageMessageEntity.image, let caption = image.getCaption(), !caption.isEmpty {
                    textSize = _captionLabel!
                        .sizeThatFits(CGSize(width: size.width - x, height: CGFloat.greatestFiniteMagnitude))
                    textSize.height = textSize.height + 12.0
                }
                setBubbleContentSize(CGSize(width: size.width, height: size.height + textSize.height))
            }
        }
        else {
            setBubbleContentSize(CGSize(width: size.width, height: size.height + textSize.height))
        }
        
        super.layoutSubviews()
        
        _imageView?.frame = CGRect(
            x: msgBackground.frame.origin.x + imageInsets.left,
            y: msgBackground.frame.origin.y + imageInsets.top,
            width: size.width,
            height: size.height
        )
        var originX = msgBackground.frame.origin.x + (x / 2)
        if _captionLabel?.textAlignment == .right {
            originX = msgBackground.frame.origin.x + msgBackground.frame.size.width - (x / 2) - textSize.width
        }
        _captionLabel!.frame = CGRect(
            x: ceil(originX),
            y: ceil(_imageView!.frame.origin.y + _imageView!.frame.size.height),
            width: ceil(textSize.width),
            height: ceil(textSize.height)
        )
        
        let mask: CALayer =
            bubbleMaskWithoutArrow(forImageSize: CGSize(
                width: _imageView!.frame.size.width,
                height: _imageView!.frame.size.height
            ))
        _imageView?.layer.mask = mask
        _imageView?.layer.masksToBounds = true

        if message.isOwnMessage {
            progressBar.frame = CGRect(
                x: _imageView!.frame.origin.x + 16.0,
                y: _imageView!.frame.origin.y + _imageView!.frame.size.height - 24.0,
                width: size.width - 32.0,
                height: 16.0
            )
            resendButton.frame = CGRect(
                x: _imageView!.frame.origin.x - kMessageScreenMargin,
                y: _imageView!.frame.origin.y + (_imageView!.frame.size.height - 32.0) / 2,
                width: 114.0,
                height: 32.0
            )
        }
        else {
            if imageMessageEntity.thumbnail == nil {
                activityIndicator.frame = CGRect(x: 72.0 + contentLeftOffset(), y: 17.0, width: 21.0, height: 21.0)
                _imageIcon!.frame = CGRect(x: 26.0 + contentLeftOffset(), y: 19.0, width: 24.0, height: 18.0)
            }
            else {
                if imageMessageEntity.thumbnail.data == nil {
                    activityIndicator.frame = CGRect(x: 72.0 + contentLeftOffset(), y: 17.0, width: 21.0, height: 21.0)
                    _imageIcon!.frame = CGRect(x: 26.0 + contentLeftOffset(), y: 19.0, width: 24.0, height: 18.0)
                }
            }
        }
    }
    
    override open func accessibilityLabelForContent() -> String! {
        if _captionLabel?.text != nil {
            return "\(BundleUtil.localizedString(forKey: "image")). \(_captionLabel!.text!))"
        }
        else {
            return BundleUtil.localizedString(forKey: "image")
        }
    }
    
    override open func showActivityIndicator() -> Bool {
        showProgressBar() == false
    }
    
    override open func showProgressBar() -> Bool {
        if message != nil {
            return message.isOwnMessage
        }
        return false
    }
    
    override open func messageTapped(_ sender: Any!) {
        let imageMessageEntity = message as! ImageMessageEntity
        if imageMessageEntity.image == nil {
            // Not loaded yet. Should we start loading again?
            if imageMessageEntity.progress == nil {
                let loader = BlobMessageLoader()
                loader.start(with: imageMessageEntity, onCompletion: { _ in
                    DDLogInfo("File image message blob load completed")
                }) { error in
                    DDLogInfo("File image message blob load failed with error: \(error!)")
                }
            }
        }
        chatVc.imageMessageTapped(imageMessageEntity)
    }
    
    override open func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        let imageMessageEntity = message as! ImageMessageEntity
        let mdmSetup = MDMSetup(setup: false)
        if action == #selector(resendMessage(_:)), imageMessageEntity.isOwnMessage,
           imageMessageEntity.sendFailed?.boolValue ?? false {
            return true
        }
        else if action == #selector(deleteMessage(_:)), imageMessageEntity.isOwnMessage,
                imageMessageEntity.progress != nil {
            // don't allow messages in progress to be deleted
            return false
        }
        else if action == #selector(shareMessage(_:)) {
            let mdmSetup = MDMSetup(setup: false)
            if mdmSetup?.disableShareMedia() == true {
                return false
            }
            return imageMessageEntity.image != nil
        }
        else if action == #selector(forwardMessage(_:)) {
            return imageMessageEntity.image != nil
        }
        else if action == #selector(copyMessage(_:)), mdmSetup?.disableShareMedia() == true {
            return false
        }
        else if action == #selector(speakMessage(_:)), _captionLabel?.text != nil {
            return true
        }
        else {
            return super.canPerformAction(action, withSender: sender)
        }
    }
    
    @objc override open func copyMessage(_ menuController: UIMenuController!) {
        let imageMessageEntity = message as! ImageMessageEntity
        if let image = imageMessageEntity.image, let caption = image.getCaption(), !caption.isEmpty {
            UIPasteboard.general.string = caption
        }
        else {
            if imageMessageEntity.image != nil, imageMessageEntity.image.data != nil {
                UIPasteboard.general.image = imageMessageEntity.image.uiImage
            }
            else {
                if imageMessageEntity.thumbnail != nil, imageMessageEntity.thumbnail.data != nil {
                    UIPasteboard.general.image = imageMessageEntity.thumbnail.uiImage
                }
            }
        }
    }
    
    override open func textForQuote() -> String! {
        _captionLabel?.text as? String ?? ""
    }
        
    override open func performPlayActionForAccessibility() -> Bool {
        messageTapped(self)
        return true
    }
    
    override open func shouldHideBubbleBackground() -> Bool {
        false
    }
    
    override open func previewViewController() -> UIViewController! {
        chatVc.headerView.getPhotoBrowser(at: message, forPeeking: true)
    }
    
    override open func previewViewController(
        for previewingContext: UIViewControllerPreviewing!,
        viewControllerForLocation location: CGPoint
    ) -> UIViewController! {
        if let controller = super.previewViewController(for: previewingContext, viewControllerForLocation: location) {
            return controller
        }
        return chatVc.headerView.getPhotoBrowser(at: message, forPeeking: true)
    }
    
    override open func updateColors() {
        super.updateColors()
    }
    
    override open func getContextMenu(_ indexPath: IndexPath!, point: CGPoint) -> UIContextMenuConfiguration! {
        if isEditing == true {
            return nil
        }
    
        // returns nil if there is no link tapped
        if let menu = contextMenuForLink(indexPath, point: point) {
            return menu
        }
        
        if let mdmSetup = MDMSetup(setup: false),
           !mdmSetup.disableShareMedia(),
           let imageMessageEntity = message as? ImageMessageEntity,
           let imageMessageImage = imageMessageEntity.image,
           imageMessageImage.data != nil {
            let conf = UIContextMenuConfiguration(
                identifier: indexPath as NSIndexPath,
                previewProvider: { () -> UIViewController? in
                    self.previewViewController()
                }
            ) { _ -> UIMenu? in
                var menuItems = super.contextMenuItems()!
                let saveImage = UIImage(systemName: "square.and.arrow.down.fill", compatibleWith: self.traitCollection)
                let saveAction = UIAction(
                    title: BundleUtil.localizedString(forKey: "save"),
                    image: saveImage,
                    identifier: nil,
                    discoverabilityTitle: nil,
                    attributes: [],
                    state: .off
                ) { _ in
                    if let image = imageMessageEntity.image, let uiImage = image.uiImage {
                        AlbumManager.shared.save(image: uiImage)
                    }
                    else {
                        DDLogError("Could not save image because image or image.uiImage was nil")
                    }
                }
                
                if self.message.isOwnMessage || self.chatVc.conversation.isGroup() {
                    menuItems.insert(saveAction, at: 0)
                }
                else {
                    menuItems.insert(saveAction, at: 1)
                }
                return UIMenu(
                    title: "",
                    image: nil,
                    identifier: nil,
                    options: .displayInline,
                    children: menuItems as! [UIMenuElement]
                )
            }
            return conf
        }
        
        return super.getContextMenu(indexPath, point: point)
    }
}

extension ChatImageMessageCell {
    // MARK: Public functions
    
    func setBaseMessage(newMessage: BaseMessage) {
        let imageMessageEntity = newMessage as! ImageMessageEntity
        
        super.message = newMessage
        
        if let thumb = imageMessageEntity.thumbnail {
            if let data = thumb.data {
                _imageView?.image = UIImage(data: data)
            }
        }
        var size = CGSize(width: 80.0, height: 40.0)
        
        if imageMessageEntity.thumbnail != nil {
            if imageMessageEntity.thumbnail.data != nil, imageMessageEntity.thumbnail.height.floatValue > 0 {
                let width = CGFloat(imageMessageEntity.thumbnail.width.floatValue)
                let height = CGFloat(imageMessageEntity.thumbnail.height.floatValue)
                let imageMessageSize = CGSize(width: width, height: height)
                size = ChatImageMessageCell.scaleImageSize(
                    toCell: imageMessageSize,
                    forTableWidth: frame.size.width,
                    isGroup: imageMessageEntity.conversation.isGroup()
                )
            }
            
            _imageView?.frame.size = size
        }
        
        if imageMessageEntity.isOwnMessage {
            _imageView?.autoresizingMask = .flexibleLeftMargin
            _imageView?.isHidden = false
            _imageIcon?.isHidden = true
        }
        else {
            if imageMessageEntity.thumbnail != nil {
                if imageMessageEntity.thumbnail.data != nil {
                    _imageView?.autoresizingMask = .flexibleLeftMargin
                    _imageView?.isHidden = false
                    _imageIcon?.isHidden = true
                }
                else {
                    _imageView?.isHidden = true
                    let image = BundleUtil.imageNamed("Landscape")
                    _imageIcon!.image = image!.withTint(Colors.textLight)
                    _imageIcon?.alpha = 0.7
                    _imageIcon?.isHidden = false
                }
            }
            else {
                _imageView?.isHidden = true
                let image = BundleUtil.imageNamed("Landscape")
                _imageIcon!.image = image!.withTint(Colors.textLight)
                _imageIcon?.alpha = 0.7
                _imageIcon?.isHidden = false
            }
        }
        
        if let image = imageMessageEntity.image, let captionText = image.getCaption(), !captionText.isEmpty {
            _captionLabel?.font = ChatMessageCell.textFont()
            let attributed = TextStyleUtils.makeAttributedString(
                from: captionText,
                with: _captionLabel!.font,
                textColor: Colors.text,
                isOwn: true,
                application: UIApplication.shared
            )
            let formattedAttributeString =
                NSMutableAttributedString(attributedString: (_captionLabel!.applyMarkup(for: attributed))!)
            _captionLabel?.attributedText = TextStyleUtils.makeMentionsAttributedString(
                for: formattedAttributeString,
                textFont: _captionLabel!.font!,
                at: _captionLabel!.textColor.withAlphaComponent(0.4),
                messageInfo: Int32(message.isOwn!.intValue),
                application: UIApplication.shared
            )
            _captionLabel?.textAlignment = captionText.textAlignment()
            _captionLabel?.isHidden = false
        }
        else {
            _captionLabel?.text = nil
            _captionLabel?.isHidden = true
        }
        
        updateColors()
        setNeedsLayout()
    }
    
    @objc func resendMessage(_ menuController: UIMenuController) {
        DDLogError("ImageMessages can not be resent anymore.")
    }
    
    @objc func speakMessage(_ menuController: UIMenuController) {
        if _captionLabel?.text != nil {
            let speakText = "\(BundleUtil.localizedString(forKey: "image")). \(_captionLabel!.text!)"
            SpeechSynthesizerManger().speak(speakText)
        }
    }
}
