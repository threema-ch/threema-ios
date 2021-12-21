//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2021 Threema GmbH
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

@objc open class ChatAnimatedGifMessageCell: ChatBlobTextMessageCell {
    override open var message: BaseMessage! {
        didSet {
            setBaseMessage(newMessage: message)
        }
    }
    
    private var _imageContentView: FLAnimatedImageView?
    private var _playButtonView: UIImageView?
    
    private var _animatedImage: FLAnimatedImage?
    private var _thumbnailImage: UIImage?
    
    private var _imageIcon: UIImageView?
    
    private var _downloadBackground: UIImageView?
    private var _downloadSizeLabel: UILabel?
    
    private var _gifDispatchQueue = DispatchQueue.init(label: "ch.threema.gif")
    
    @objc override public init!(style: UITableViewCell.CellStyle, reuseIdentifier: String!, transparent: Bool) {
        super.init(style: style, reuseIdentifier: reuseIdentifier, transparent: transparent)
        
        setBubbleHighlighted(false)
        
        setupViews()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension ChatAnimatedGifMessageCell {
    // MARK: Private functions
    
    private func setupViews() {
        
        _imageContentView = FLAnimatedImageView()
        _imageContentView?.clearsContextBeforeDrawing = false
        contentView.addSubview(_imageContentView!)
        
        if #available(iOS 13.0, *) {
            _playButtonView = UIImageView.init(image: BundleUtil.imageNamed("Play")?.withTintColor(Colors.white()))
        } else {
            _playButtonView = UIImageView.init(image: BundleUtil.imageNamed("Play")?.withTint(Colors.white()))
        }
        _playButtonView?.frame = CGRect.init(x: 0.0, y: 0.0, width: 32.0, height: 32.0)
        _playButtonView?.alpha = 0.8
        _imageContentView!.addSubview(_playButtonView!)
        
        _imageIcon = UIImageView.init(image: BundleUtil.imageNamed("Landscape")?.withTint(Colors.fontLight()))
        _imageIcon?.clearsContextBeforeDrawing = false
        contentView.addSubview(_imageIcon!)
        
        _captionLabel = ChatTextMessageCell.makeAttributedLabel(withFrame: self.bounds)
        _captionLabel?.tapDelegate = self
        _captionLabel?.longPressDelegate = self
        contentView.addSubview(_captionLabel!)
        
        _downloadBackground = UIImageView.init(image: UIImage.init(named: "VideoDownloadBg")?.resizableImage(withCapInsets: UIEdgeInsets.init(top: 0, left: 32, bottom: 0, right: 0)))
        _downloadBackground!.isOpaque = false

        _downloadSizeLabel = UILabel.init()
        _downloadSizeLabel?.backgroundColor = .clear
        _downloadSizeLabel?.isOpaque = false
        _downloadSizeLabel?.font = UIFont.boldSystemFont(ofSize: 12)
        _downloadSizeLabel?.textColor = Colors.white()
        _downloadSizeLabel?.textAlignment = .right
        _downloadSizeLabel?.adjustsFontSizeToFitWidth = true
        _downloadBackground!.addSubview(_downloadSizeLabel!)
        _imageContentView!.addSubview(_downloadSizeLabel!)
        
        if #available(iOS 11.0, *) {
            _imageContentView?.accessibilityIgnoresInvertColors = true
        }
        
        setupColors()
    }
    
    private func setupAnimatedImage() {
        let fileMessage = message as! FileMessage
        _gifDispatchQueue.async {
            if let fileMessageData = fileMessage.data {
                self._animatedImage = FLAnimatedImage.init(animatedGIFData: fileMessageData.data)
                self.enableAnimation(true)
            } else {
                DDLogWarn("FileMessageData was nil")
            }
        }
    }
    
    private func enableAnimation(_ enable: Bool) {
        DispatchQueue.main.async {
            if (self._animatedImage != nil) && enable {
                self._imageContentView?.animatedImage = self._animatedImage
                self._imageContentView?.isHidden = false
                self._imageIcon?.isHidden = true
                self._playButtonView?.isHidden = true
                self._imageContentView?.startAnimating()
            }
            else if (self._thumbnailImage != nil) {
                self._imageContentView?.image = self._thumbnailImage
                self._imageContentView?.isHidden = false
                self._imageIcon?.isHidden = true
                self._playButtonView?.isHidden = false
            }
            else {
                self._imageIcon?.isHidden = false
                self._imageContentView?.isHidden = true
                self._playButtonView?.isHidden = true
            }
        }
    }
    
    private func toggleAnimation() {
        enableAnimation(!_imageContentView!.isAnimating)
    }
}

extension ChatAnimatedGifMessageCell {
    // MARK: Override functions
    
    @objc override open class func height(for message: BaseMessage!, forTableWidth tableWidth: CGFloat) -> CGFloat {
        let fileMessage = message as! FileMessage
        
        var cellHeight: CGFloat = 40.0
        var scaledSize = CGSize.init()
        
        var thumbnailZeroHeight = false
        if let thumbnail = fileMessage.thumbnail, thumbnail.height.floatValue <= 0.0 {
            thumbnailZeroHeight = true
        }
        
        // workaround for backward compatibility, create new thumbnail when not available yet or invalid
        if fileMessage.thumbnail == nil || thumbnailZeroHeight,
           let fileMessageData = fileMessage.data {
            let animImage = FLAnimatedImage.init(animatedGIFData: fileMessageData.data)
            if let thumbnail = MediaConverter.getThumbnailFor(animImage?.posterImage) {
                let entityManager = EntityManager.init()
                entityManager.performAsyncBlockAndSafe {
                    let dbThumbnail = entityManager.entityCreator.imageData()
                    dbThumbnail?.data = thumbnail.jpegData(compressionQuality: CGFloat(kJPEGCompressionQualityLow))
                    dbThumbnail?.width = NSNumber(value: Float(thumbnail.size.width))
                    dbThumbnail?.height = NSNumber(value: Float(thumbnail.size.height))
                    
                    fileMessage.thumbnail = dbThumbnail
                }
            }
        }
        
        if let thumbnail = fileMessage.thumbnail, thumbnail.data != nil && thumbnail.height.floatValue > 0 {
            let width: CGFloat = CGFloat(thumbnail.width.floatValue)
            let height: CGFloat = CGFloat(thumbnail.height.floatValue)
            let size: CGSize = CGSize.init(width: width, height: height)
            scaledSize = ChatAnimatedGifMessageCell.scaleImageSize(toCell: size, forTableWidth: tableWidth)
            if scaledSize.height != scaledSize.height || scaledSize.height < 0 {
                scaledSize.height = 40.0
            }
            cellHeight = scaledSize.height - 17.0
        }
        
        cellHeight = cellHeight + ChatBlobTextMessageCell.calculateCaptionHeight(scaledSize: scaledSize, fileMessage: fileMessage)
        
        return cellHeight
    }
    
    override public func layoutSubviews() {
        guard let fileMessage = message as? FileMessage else {
            DDLogError("Message is not a FileMessage.")
            return
        }
        let imageInsets = UIEdgeInsets.init(top: 5, left: 5, bottom: 5, right: 5)
        if let thumbnail = fileMessage.thumbnail {
            var size = CGSize.init(width: CGFloat(thumbnail.width.floatValue), height: CGFloat(thumbnail.height.floatValue))
            var textSize: CGSize = CGSize.init(width: 0.0, height: 0.0)
            let x: CGFloat = 30.0
            
            /* scale to fit maximum cell size */
            size = ChatAnimatedGifMessageCell.scaleImageSize(toCell: size, forTableWidth: frame.size.width)
            if size.height != size.height {
                size.height = 120.0
            }
            if size.width != size.width {
                size.width = 120.0
            }
            
            if let caption = fileMessage.caption, caption.count > 0 {
                textSize = _captionLabel!.sizeThatFits(CGSize.init(width: size.width - x, height: CGFloat.greatestFiniteMagnitude))
                textSize.height = textSize.height + 12.0
            }
            
            let bubbleSize = CGSize.init(width: size.width + imageInsets.left + imageInsets.right, height: size.height + imageInsets.top + imageInsets.bottom + textSize.height)
            setBubble(bubbleSize)
            
            super.layoutSubviews()
            
            _imageContentView!.frame = CGRect.init(x: msgBackground.frame.origin.x + imageInsets.left, y: msgBackground.frame.origin.y + imageInsets.top, width: size.width, height: size.height)
            var originX = msgBackground.frame.origin.x + (x/2)
            if _captionLabel?.textAlignment == .right {
                originX = msgBackground.frame.origin.x + msgBackground.frame.size.width - (x/2) - textSize.width
            }
            _captionLabel!.frame  = CGRect.init(x:ceil(originX), y: ceil(_imageContentView!.frame.origin.y + _imageContentView!.frame.size.height), width: ceil(textSize.width), height: ceil(textSize.height))

            let mask: CALayer = bubbleMaskWithoutArrow(forImageSize: CGSize.init(width: _imageContentView!.frame.size.width, height: _imageContentView!.frame.size.height))
            _imageContentView?.layer.mask = mask
            _imageContentView?.layer.masksToBounds = true
            
            if fileMessage.isOwn != nil, fileMessage.isOwn.boolValue {
                resendButton.frame = CGRect.init(x: _imageContentView!.frame.origin.x - kMessageScreenMargin, y: _imageContentView!.frame.origin.y + (_imageContentView!.frame.size.height - 32) / 2, width: 114, height: 32)
            }
            
            progressBar.frame = CGRect.init(x: _imageContentView!.frame.origin.x + 16.0, y: _imageContentView!.frame.origin.y + _imageContentView!.frame.size.height - 40.0, width: size.width - 32.0, height: 16.0)
                        
            /* download size label */
            _downloadBackground!.frame = CGRect.init(x: 0, y: 1, width: _imageContentView!.frame.size.width + 1, height: 18.0)
            _downloadSizeLabel!.frame = CGRect.init(x: _downloadBackground!.frame.size.width / 2, y: 1, width: _downloadBackground!.frame.size.width / 2 - 12, height: 16.0)
            
            if bubbleSize.height > 44.0 && bubbleSize.width > 44.0 {
                _playButtonView!.frame = CGRect.init(x: (_imageContentView!.frame.size.width / 2) - 22.0, y: (_imageContentView!.frame.size.height / 2) - 22.0 - 2.0, width: 44.0, height: 44.0)
            } else {
                var min = Swift.min(bubbleSize.width, bubbleSize.height)
                min = min - 20.0
                _playButtonView!.frame = CGRect.init(x: (bubbleSize.width / 2) - (min/2), y: (bubbleSize.height / 2) - (min/2) - 2.0, width: min, height: min)
            }
        }
    }

    override open func accessibilityLabelForContent() -> String! {
        if _captionLabel?.text != nil {
            return "\(BundleUtil.localizedString(forKey: "file") ?? "File"). \(_captionLabel!.text!))"
        } else {
            return BundleUtil.localizedString(forKey: "file")
        }
    }
    
    override open func showActivityIndicator() -> Bool {
        return showProgressBar() == false
    }
    
    override open func showProgressBar() -> Bool {
        return true
    }
    
    override open func messageTapped(_ sender: Any!) {
        let fileMessage = message as! FileMessage
        if fileMessage.data == nil {
            let loader = AnimGifMessageLoader()
            loader.start(with: fileMessage, onCompletion: { (baseMessage) in
                DDLogInfo("File gif message blob load completed")
                self._downloadBackground?.isHidden = true
                self.message = baseMessage
            }) { (error) in
                DDLogInfo("File gif message blob load failed with error: \(error!)")
                if (error! as NSError).code != kErrorCodeUserCancelled {
                    UIAlertTemplate.showAlert(owner: AppDelegate.shared().currentTopViewController(), title: error?.localizedDescription, message: (error! as NSError).localizedFailureReason, actionOk: nil)
                }
            }
        }
        toggleAnimation()
    }
    

    override open func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {        
        let fileMessage = message as! FileMessage
        let mdmSetup = MDMSetup.init(setup: false)
        if action == #selector(resendMessage(_:)) && fileMessage.isOwn.boolValue && fileMessage.sendFailed.boolValue {
            return true
        }
        else if action == #selector(deleteMessage(_:)) && fileMessage.isOwn.boolValue && fileMessage.progress != nil {
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
            return fileMessage.data != nil
        }
        else if action == #selector(forwardMessage(_:)) {
            if #available(iOS 13.0, *) {
                return fileMessage.data != nil
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
        let fileMessage = message as! FileMessage
        if let caption = fileMessage.caption, caption.count > 0 {
            UIPasteboard.general.string = fileMessage.caption
        } else {
            if let fileMessageData = fileMessage.data, let fileMessageDataData = fileMessageData.data {
                UIPasteboard.general.setData(fileMessageDataData, forPasteboardType: "com.compuserve.gif")
            } else {
                if let thumbnail = fileMessage.thumbnail, let thumbnailData = thumbnail.data {
                    UIPasteboard.general.image = UIImage.init(data: thumbnailData)
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
        if let fileMessage = message as? FileMessage, let thumbnail = fileMessage.thumbnail, thumbnail.data != nil, let type = fileMessage.type, type.intValue == 2 {
            if let captionText = fileMessage.caption, captionText.count > 0 {
                return false
            }
            return true
        }
        return false
    }
        
    open override func previewViewController() -> UIViewController! {
        if let fileMessage = message as? FileMessage, !fileMessage.renderFileGifMessage() {
            return chatVc.headerView.getPhotoBrowser(at: message, forPeeking: true)
        }
        return nil

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

        
        let fileMessage = message as! FileMessage
        if let fileMessageData = fileMessage.data {
            if fileMessageData.data != nil {
                let conf = UIContextMenuConfiguration.init(identifier: indexPath as NSIndexPath, previewProvider: { () -> UIViewController? in
                    return self.previewViewController()
                }) { (suggestedActions) -> UIMenu? in
                    var menuItems = super.contextMenuItems()!
                    let saveImage = UIImage.init(systemName: "square.and.arrow.down.fill", compatibleWith: self.traitCollection)
                    let saveAction = UIAction.init(title: BundleUtil.localizedString(forKey: "save"), image: saveImage, identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off) { (action) in
                        let filename = FileUtility.getTemporarySendableFileName(base: "gif")
                        let tmpFileUrl = fileMessage.tmpURL(filename)
                        fileMessage.exportData(to: tmpFileUrl)
                        AlbumManager.shared.save(url: tmpFileUrl!, isVideo: false) { (success) in
                            do {
                                try FileManager.default.removeItem(at: tmpFileUrl!)
                            }
                            catch {
                            }
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
            } else {
                return super.getContextMenu(indexPath, point: point)
            }
        } else {
            return super.getContextMenu(indexPath, point: point)
        }
    }
    
    open override func willDisplay() {
        super.willDisplay()
        enableAnimation(true)
    }
    
    open override func didEndDisplaying() {
        super.didEndDisplaying()
        enableAnimation(false)
    }
}

extension ChatAnimatedGifMessageCell {
    // MARK: Public functions
    
    func setBaseMessage(newMessage: BaseMessage) {
        _thumbnailImage = nil
        _animatedImage = nil
        
        let fileMessage = newMessage as! FileMessage
        
        super.message = newMessage
        
        if let thumbnail = fileMessage.thumbnail, let thumb = thumbnail.uiImage {
            _thumbnailImage = thumb
        }

        var size = CGSize.init(width: 80.0, height: 40.0)
        
        if let thumbnail = fileMessage.thumbnail {
            if thumbnail.data != nil && thumbnail.height.floatValue > 0 {
                let width: CGFloat = CGFloat(thumbnail.width.floatValue)
                let height: CGFloat = CGFloat(thumbnail.height.floatValue)
                let fileMessageSize: CGSize = CGSize.init(width: width, height: height)
                size = ChatAnimatedGifMessageCell.scaleImageSize(toCell: fileMessageSize, forTableWidth: frame.size.width)
            }
            
            _imageContentView!.frame.size = size
        }
        
        var autoresizingMask: AutoresizingMask = .flexibleRightMargin
        if fileMessage.isOwn.boolValue {
            autoresizingMask = .flexibleLeftMargin
        }
        _imageContentView?.autoresizingMask = autoresizingMask
        _downloadBackground?.autoresizingMask = autoresizingMask
        _downloadSizeLabel?.autoresizingMask = autoresizingMask
        
        if let captionText = fileMessage.caption, captionText.count > 0 {
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
        
        if let fileMessageData = fileMessage.data, fileMessageData.data != nil {
            setupAnimatedImage()
            _downloadBackground?.isHidden = true
        } else {
            _downloadSizeLabel?.text = Utils.formatDataLength(CGFloat(fileMessage.fileSize!.floatValue))
            _downloadBackground?.isHidden = false
        }
        
        enableAnimation(true)
        
        setupColors()
        self.setNeedsLayout()
    }
    
    @objc func resendMessage(_ menuController: UIMenuController) {
        let fileMessage = message as! FileMessage
        let sender: FileMessageSender = FileMessageSender.init()
        sender.retryMessage(fileMessage)
    }
}
