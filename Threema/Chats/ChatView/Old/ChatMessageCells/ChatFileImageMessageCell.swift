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
import ThreemaFramework

@objc open class ChatFileImageMessageCell: ChatBlobTextMessageCell {
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

extension ChatFileImageMessageCell {
    // MARK: Override functions
    
    @objc override open class func height(for message: BaseMessage!, forTableWidth tableWidth: CGFloat) -> CGFloat {
        let fileMessageEntity = message as! FileMessageEntity
        
        var cellHeight: CGFloat = 40.0
        var scaledSize = CGSize()
        if let thumbnail = fileMessageEntity.thumbnail, thumbnail.data != nil, thumbnail.height.floatValue > 0 {
            let width = CGFloat(thumbnail.width.floatValue)
            let height = CGFloat(thumbnail.height.floatValue)
            let size = CGSize(width: width, height: height)
            scaledSize = ChatFileImageMessageCell.scaleImageSize(
                toCell: size,
                forTableWidth: tableWidth,
                isGroup: fileMessageEntity.isGroupMessage
            )
            if scaledSize.height != scaledSize.height || scaledSize.height < 0 {
                scaledSize.height = 40.0
            }
            cellHeight = scaledSize.height - 17.0
        }
        
        cellHeight = cellHeight + ChatBlobTextMessageCell.calculateCaptionHeight(
            scaledSize: scaledSize,
            fileMessageEntity: fileMessageEntity
        )
        
        return cellHeight
    }
            
    override public func layoutSubviews() {
        let fileMessageEntity = message as! FileMessageEntity
        
        var textSize = CGSize(width: 0.0, height: 0.0)
        var size = CGSize(width: 80.0, height: 40.0)
        let x: CGFloat = 30.0
        let imageInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        if let thumbnail = fileMessageEntity.thumbnail {
            if thumbnail.data != nil, thumbnail.height.floatValue > 0 {
                let width = CGFloat(thumbnail.width.floatValue)
                let height = CGFloat(thumbnail.height.floatValue)
                let fileMessageSize = CGSize(width: width, height: height)
                size = ChatFileImageMessageCell.scaleImageSize(
                    toCell: fileMessageSize,
                    forTableWidth: frame.size.width,
                    isGroup: fileMessageEntity.isGroupMessage
                )
                
                if let caption = fileMessageEntity.caption, !caption.isEmpty {
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
                if let caption = fileMessageEntity.caption, !caption.isEmpty {
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
            if fileMessageEntity.thumbnail == nil {
                activityIndicator.frame = CGRect(x: 72.0 + contentLeftOffset(), y: 17.0, width: 21.0, height: 21.0)
                _imageIcon!.frame = CGRect(x: 26.0 + contentLeftOffset(), y: 19.0, width: 24.0, height: 18.0)
            }
            else {
                if let thumbnail = fileMessageEntity.thumbnail, thumbnail.data == nil {
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
        let fileMessageEntity = message as! FileMessageEntity
        if fileMessageEntity.data == nil {
            // Not loaded yet. Should we start loading again?
            if fileMessageEntity.progress == nil {
                let loader = BlobMessageLoader()
                loader.start(with: fileMessageEntity, onCompletion: { _ in
                    DDLogInfo("File image message blob load completed")
                    self.chatVc.fileImageMessageTapped(fileMessageEntity)
                }) { error in
                    DDLogInfo("File image message blob load failed with error: \(error!)")
                }
            }
        }
        else {
            chatVc.fileImageMessageTapped(fileMessageEntity)
        }
    }
    
    override open func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        let fileMessageEntity = message as! FileMessageEntity
        let mdmSetup = MDMSetup(setup: false)
        if action == #selector(resendMessage(_:)), fileMessageEntity.isOwnMessage,
           fileMessageEntity.sendFailed?.boolValue ?? false {
            return true
        }
        else if action == #selector(deleteMessage(_:)), fileMessageEntity.isOwnMessage,
                fileMessageEntity.progress != nil {
            // don't allow messages in progress to be deleted
            return false
        }
        else if action == #selector(shareMessage(_:)) {
            let mdmSetup = MDMSetup(setup: false)
            if mdmSetup?.disableShareMedia() == true {
                return false
            }
            return fileMessageEntity.data != nil
        }
        else if action == #selector(forwardMessage(_:)) {
            return fileMessageEntity.data != nil
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
        let fileMessageEntity = message as! FileMessageEntity
        if let caption = fileMessageEntity.caption, !caption.isEmpty {
            UIPasteboard.general.string = fileMessageEntity.caption
        }
        else {
            if let fileMessageData = fileMessageEntity.data, let fileMessageDataData = fileMessageData.data {
                UIPasteboard.general.image = UIImage(data: fileMessageDataData)
            }
            else {
                if let thumbnail = fileMessageEntity.thumbnail, let thumbnailData = thumbnail.data {
                    UIPasteboard.general.image = UIImage(data: thumbnailData)
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
        let fileMessageEntity = message as? FileMessageEntity
        if fileMessageEntity?.thumbnail != nil {
            if fileMessageEntity!.thumbnail!.data != nil {
                if let messageType = fileMessageEntity?.type, messageType.intValue == 2 {
                    return true
                }
            }
        }
        return false
    }
        
    override open func previewViewController() -> UIViewController! {
        if let fileMessageEntity = message as? FileMessageEntity, !fileMessageEntity.renderStickerFileMessage() {
            return chatVc.headerView.getPhotoBrowser(at: message, forPeeking: true)
        }
        return nil
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
           let fileMessageEntity = message as? FileMessageEntity,
           let fileMessageData = fileMessageEntity.data,
           let fileMessageDataData = fileMessageData.data {
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
                    guard let image = UIImage(data: fileMessageDataData) else {
                        DDLogError("Could not create image from filemessagedata")
                        return
                    }
                    AlbumManager.shared.save(image: image)
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

extension ChatFileImageMessageCell {
    // MARK: Public functions
    
    func setBaseMessage(newMessage: BaseMessage) {
        let fileMessageEntity = newMessage as! FileMessageEntity
        
        super.message = newMessage
        
        if let thumb = fileMessageEntity.thumbnail, let thumbData = thumb.data {
            _imageView?.image = UIImage(data: thumbData)
        }
        var size = CGSize(width: 80.0, height: 40.0)
        
        if let thumbnail = fileMessageEntity.thumbnail {
            if thumbnail.data != nil, thumbnail.height.floatValue > 0 {
                let width = CGFloat(thumbnail.width.floatValue)
                let height = CGFloat(thumbnail.height.floatValue)
                let fileMessageSize = CGSize(width: width, height: height)
                size = ChatFileImageMessageCell.scaleImageSize(
                    toCell: fileMessageSize,
                    forTableWidth: frame.size.width,
                    isGroup: fileMessageEntity.isGroupMessage
                )
            }
            
            _imageView?.frame.size = size
        }
                
        if fileMessageEntity.isOwnMessage {
            _imageView?.autoresizingMask = .flexibleLeftMargin
            _imageView?.isHidden = false
            _imageIcon?.isHidden = true
        }
        else {
            if let thumbnail = fileMessageEntity.thumbnail {
                if thumbnail.data != nil {
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
        
        if let captionText = fileMessageEntity.caption, !captionText.isEmpty, fileMessageEntity.shouldShowCaption() {
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
        let fileMessageEntity = message as! FileMessageEntity
        
        let entityManager = EntityManager()
        entityManager.performSyncBlockAndSafe {
            // swiftformat:disable acronyms
            fileMessageEntity.id = NaClCrypto.shared().randomBytes(kMessageIdLen)
        }
        
        let sender = Old_FileMessageSender()
        sender.retryMessage(fileMessageEntity)
    }
    
    @objc func speakMessage(_ menuController: UIMenuController) {
        if _captionLabel?.text != nil {
            let speakText = "\(BundleUtil.localizedString(forKey: "image")). \(_captionLabel!.text!)"
            SpeechSynthesizerManger().speak(speakText)
        }
    }
}
