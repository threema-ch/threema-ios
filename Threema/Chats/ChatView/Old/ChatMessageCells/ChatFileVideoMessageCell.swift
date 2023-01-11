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

@objc open class ChatFileVideoMessageCell: ChatBlobTextMessageCell {
    override open var message: BaseMessage! {
        didSet {
            setBaseMessage(newMessage: message)
        }
    }
    
    private var _thumbnailView: UIImageView?
    private var _durationBackground: UIImageView?
    private var _downloadBackground: UIImageView?
    private var _playImageView: UIImageView?
    private var _durationLabel: UILabel?
    private var _downloadSizeLabel: UILabel?
    
    private var _observedMessages = [Data]()
    
    @objc override public init!(style: UITableViewCell.CellStyle, reuseIdentifier: String!, transparent: Bool) {
        super.init(style: style, reuseIdentifier: reuseIdentifier, transparent: transparent)
        
        self._thumbnailView = UIImageView()
        _thumbnailView!.clearsContextBeforeDrawing = false
        contentView.addSubview(_thumbnailView!)
        
        self
            ._durationBackground = UIImageView(
                image: UIImage(named: "VideoDurationBg")?
                    .resizableImage(withCapInsets: UIEdgeInsets(top: 0, left: 32, bottom: 0, right: 0))
            )
        _durationBackground?.isOpaque = false
        _thumbnailView!.addSubview(_durationBackground!)
        
        self
            ._downloadBackground = UIImageView(
                image: UIImage(named: "VideoDownloadBg")?
                    .resizableImage(withCapInsets: UIEdgeInsets(top: 0, left: 32, bottom: 0, right: 0))
            )
        _downloadBackground!.isOpaque = false
        _thumbnailView!.addSubview(_downloadBackground!)
        
        self._durationLabel = UILabel()
        _durationLabel!.backgroundColor = .clear
        _durationLabel!.isOpaque = false
        _durationLabel!.font = UIFont.boldSystemFont(ofSize: 12)
        _durationLabel!.textColor = Colors.white
        _durationLabel!.textAlignment = .right
        _durationBackground?.addSubview(_durationLabel!)
            
        self._downloadSizeLabel = UILabel()
        _downloadSizeLabel!.backgroundColor = .clear
        _downloadSizeLabel!.isOpaque = false
        _downloadSizeLabel!.font = UIFont.boldSystemFont(ofSize: 12)
        _downloadSizeLabel!.textColor = Colors.white
        _downloadSizeLabel!.textAlignment = .right
        _downloadSizeLabel!.adjustsFontSizeToFitWidth = true
        _downloadBackground!.addSubview(_downloadSizeLabel!)
            
        _thumbnailView?.accessibilityIgnoresInvertColors = true
        
        self._playImageView = UIImageView(image: BundleUtil.imageNamed("Play")?.withTintColor(Colors.playButtonTint))
        _thumbnailView!.addSubview(_playImageView!)
        
        _captionLabel = ChatTextMessageCell.makeAttributedLabel(withFrame: bounds)
        _captionLabel?.tapDelegate = self
        _captionLabel?.longPressDelegate = self
        contentView.addSubview(_captionLabel!)

        updateColors()
    }
    
    deinit {
        if message != nil {
            message.removeObserver(self, forKeyPath: "data")
            _observedMessages.removeAll()
        }
    }
}

extension ChatFileVideoMessageCell {
    // MARK: Override functions
    
    @objc override open class func height(for message: BaseMessage!, forTableWidth tableWidth: CGFloat) -> CGFloat {
        let fileMessageEntity = message as! FileMessageEntity
        
        var cellHeight: CGFloat = 40.0
        var scaledSize = CGSize()
        if let thumbnail = fileMessageEntity.thumbnail, thumbnail.data != nil, thumbnail.height.floatValue > 0 {
            let width = CGFloat(thumbnail.width.floatValue)
            let height = CGFloat(thumbnail.height.floatValue)
            let size = CGSize(width: width, height: height)
            scaledSize = ChatFileVideoMessageCell.scaleImageSize(
                toCell: size,
                forTableWidth: tableWidth,
                isGroup: fileMessageEntity.conversation.isGroup()
            )
            if scaledSize.height != scaledSize.height || scaledSize.height < 0 {
                scaledSize.height = 120.0
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
        let imageInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        if let thumbnail = fileMessageEntity.thumbnail {
            var size = CGSize(width: CGFloat(thumbnail.width.floatValue), height: CGFloat(thumbnail.height.floatValue))
            var textSize = CGSize(width: 0.0, height: 0.0)
            let x: CGFloat = 30.0
            
            // scale to fit maximum cell size
            size = ChatFileVideoMessageCell.scaleImageSize(
                toCell: size,
                forTableWidth: frame.size.width,
                isGroup: fileMessageEntity.conversation.isGroup()
            )
            if size.height != size.height {
                size.height = 120.0
            }
            if size.width != size.width {
                size.width = 120.0
            }
            
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
            
            super.layoutSubviews()

            _thumbnailView!.frame = CGRect(
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
                y: ceil(_thumbnailView!.frame.origin.y + _thumbnailView!.frame.size.height),
                width: ceil(textSize.width),
                height: ceil(textSize.height)
            )

            let mask: CALayer =
                bubbleMaskWithoutArrow(forImageSize: CGSize(
                    width: _thumbnailView!.frame.size.width,
                    height: _thumbnailView!.frame.size.height
                ))
            _thumbnailView?.layer.mask = mask
            _thumbnailView?.layer.masksToBounds = true
            
            if fileMessageEntity.isOwnMessage {
                resendButton.frame = CGRect(
                    x: _thumbnailView!.frame.origin.x - kMessageScreenMargin,
                    y: _thumbnailView!.frame.origin.y + (_thumbnailView!.frame.size.height - 32) / 2,
                    width: 114,
                    height: 32
                )
            }
            
            progressBar.frame = CGRect(
                x: _thumbnailView!.frame.origin.x + 16.0,
                y: _thumbnailView!.frame.origin.y + _thumbnailView!.frame.size.height - 40.0,
                width: size.width - 32.0,
                height: 16.0
            )
            
            // duration label
            _durationBackground!.frame = CGRect(
                x: 0,
                y: _thumbnailView!.frame.size.height - 22.0,
                width: _thumbnailView!.frame.size.width + 1,
                height: 18.0
            )
            _durationLabel!.frame = CGRect(
                x: _durationBackground!.frame.size.width / 2,
                y: 0,
                width: _durationBackground!.frame.size.width / 2 - 12,
                height: 16.0
            )
            
            // download size label
            _downloadBackground!.frame = CGRect(x: 0, y: 1, width: _thumbnailView!.frame.size.width + 1, height: 18.0)
            _downloadSizeLabel!.frame = CGRect(
                x: _downloadBackground!.frame.size.width / 2,
                y: 1,
                width: _downloadBackground!.frame.size.width / 2 - 12,
                height: 16.0
            )
            
            if bubbleSize.height > 44.0, bubbleSize.width > 44.0 {
                _playImageView!.frame = CGRect(
                    x: (_thumbnailView!.frame.size.width / 2) - 22.0,
                    y: (_thumbnailView!.frame.size.height / 2) - 22.0 - 2.0,
                    width: 44.0,
                    height: 44.0
                )
            }
            else {
                var min = Swift.min(bubbleSize.width, bubbleSize.height)
                min = min - 20.0
                _playImageView!.frame = CGRect(
                    x: (bubbleSize.width / 2) - (min / 2),
                    y: (bubbleSize.height / 2) - (min / 2) - 2.0,
                    width: min,
                    height: min
                )
            }
        }
        else {
            var textSize = CGSize(width: 0.0, height: 0.0)
            let size = CGSize(width: 80.0, height: 40.0)
            let x: CGFloat = 30.0
            
            if let caption = fileMessageEntity.caption, !caption.isEmpty {
                textSize = _captionLabel!
                    .sizeThatFits(CGSize(width: size.width - x, height: CGFloat.greatestFiniteMagnitude))
                textSize.height = textSize.height + 12.0
            }
            setBubbleContentSize(CGSize(width: size.width, height: size.height + textSize.height))
        }
    }
     
    override public func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        
        if let objerveObject = object as? BaseMessage {
            if objerveObject == message, keyPath == "data" {
                updateDownloadSize()
            }
        }
    }
    
    override open func accessibilityLabelForContent() -> String! {
        let fileMessageEntity = message as! FileMessageEntity
        
        let duration = fileMessageEntity.duration!.intValue
        
        let preText =
            "\(BundleUtil.localizedString(forKey: "video")), \(duration) \(BundleUtil.localizedString(forKey: "seconds"))"
        if _captionLabel?.text != nil {
            return "\(preText). \(_captionLabel!.text!))"
        }
        
        return preText
    }
        
    override open func messageTapped(_ sender: Any!) {
        let fileMessageEntity = message as! FileMessageEntity
        chatVc.fileVideoMessageTapped(fileMessageEntity)
    }
    
    override open func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        let fileMessageEntity = message as! FileMessageEntity
        if action == #selector(resendMessage(_:)), fileMessageEntity.isOwnMessage,
           fileMessageEntity.sendFailed?.boolValue ?? false {
            return true
        }
        else if action == #selector(deleteMessage(_:)), fileMessageEntity.isOwnMessage,
                fileMessageEntity.progress != nil {
            // don't allow messages in progress to be deleted
            return false
        }
        else if action == #selector(copyMessage(_:)), _captionLabel?.text != nil {
            return true
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
            UIPasteboard.general.string = caption
        }
        else {
            if let fileMessageData = fileMessageEntity.data, let fileMessageDataData = fileMessageData.data {
                UIPasteboard.general.setData(fileMessageDataData, forPasteboardType: fileMessageEntity.blobGetUTI()!)
            }
        }
    }
            
    override open func performPlayActionForAccessibility() -> Bool {
        messageTapped(self)
        return true
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
                    let fileName = String(format: "%f.%@", Date().timeIntervalSinceReferenceDate, MEDIA_EXTENSION_VIDEO)
                    let tmpurl = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
                    do {
                        try fileMessageDataData.write(to: tmpurl)
                        AlbumManager.shared.saveMovieToLibrary(movieURL: tmpurl) { _ in
                            do {
                                try FileManager.default.removeItem(atPath: tmpurl.path)
                            }
                            catch {
                                DDLogWarn("Remove moviefile to temporary file failed")
                            }
                        }
                    }
                    catch {
                        DDLogWarn("Writing moviefile to temporary file failed")
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

extension ChatFileVideoMessageCell {
    // MARK: Public functions
        
    func setBaseMessage(newMessage: BaseMessage) {
        if message != nil {
            if let index = _observedMessages.firstIndex(of: message.id) {
                message.removeObserver(self, forKeyPath: "data")
                _observedMessages.remove(at: index)
            }
        }
        
        let fileMessageEntity = newMessage as! FileMessageEntity

        super.message = newMessage
        
        if !chatVc.isOpenWithForceTouch {
            _observedMessages.append(message.id)
            message.addObserver(self, forKeyPath: "data", options: [], context: nil)
        }

        if let thumbnail = fileMessageEntity.thumbnail, let thumbnailUiImage = thumbnail.uiImage {
            _thumbnailView?.image = thumbnailUiImage
        }
        
        var autoresizingMask: AutoresizingMask = .flexibleRightMargin
        if fileMessageEntity.isOwnMessage {
            autoresizingMask = .flexibleLeftMargin
        }
        _thumbnailView?.autoresizingMask = autoresizingMask
        _durationBackground?.autoresizingMask = autoresizingMask
        _durationLabel?.autoresizingMask = autoresizingMask
        _downloadBackground?.autoresizingMask = autoresizingMask
        _downloadSizeLabel?.autoresizingMask = autoresizingMask

        if let seconds = fileMessageEntity.duration?.intValue {
            _durationLabel?.text = DateFormatter.timeFormatted(seconds)
        }
        else {
            _durationLabel?.text = nil
        }
        
        _downloadSizeLabel!.text = ThreemaUtilityObjC.formatDataLength(CGFloat(fileMessageEntity.fileSize!.floatValue))
        
        updateDownloadSize()
        
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

extension ChatFileVideoMessageCell {
    // MARK: Private functions
    
    private func updateDownloadSize() {
        let fileMessageEntity = message as! FileMessageEntity
        if fileMessageEntity.data != nil {
            _downloadBackground?.image = UIImage(named: "VideoDownloadBgDownloaded")?
                .resizableImage(withCapInsets: UIEdgeInsets(top: 0, left: 32, bottom: 0, right: 0))
        }
        else {
            _downloadBackground?.image = UIImage(named: "VideoDownloadBg")?
                .resizableImage(withCapInsets: UIEdgeInsets(top: 0, left: 32, bottom: 0, right: 0))
        }
    }
}
