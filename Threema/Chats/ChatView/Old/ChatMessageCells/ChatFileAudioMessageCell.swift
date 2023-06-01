//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2023 Threema GmbH
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
import UIKit

@objc open class ChatFileAudioMessageCell: ChatBlobTextMessageCell {
    override open var message: BaseMessage! {
        didSet {
            setBaseMessage(newMessage: message)
        }
    }
    
    private var _audioIcon: UIImageView?
    private var _durationLabel: UILabel?
        
    @objc override public init!(style: UITableViewCell.CellStyle, reuseIdentifier: String!, transparent: Bool) {
        super.init(style: style, reuseIdentifier: reuseIdentifier, transparent: transparent)

        self._audioIcon = UIImageView(image: BundleUtil.imageNamed("Microphone"))
        contentView.addSubview(_audioIcon!)
        
        self._durationLabel = UILabel()
        _durationLabel?.clearsContextBeforeDrawing = false
        _durationLabel?.backgroundColor = .clear
        _durationLabel?.numberOfLines = 0
        _durationLabel?.lineBreakMode = .byWordWrapping
        _durationLabel?.font = ChatFileAudioMessageCell.textFont()
        contentView.addSubview(_durationLabel!)
        
        _captionLabel = ChatTextMessageCell.makeAttributedLabel(withFrame: bounds)
        _captionLabel?.tapDelegate = self
        _captionLabel?.longPressDelegate = self
        contentView.addSubview(_captionLabel!)

        _audioIcon?.accessibilityIgnoresInvertColors = true
        
        updateColors()
    }
    
    public class func displayText(fileMessageEntity: FileMessageEntity) -> String {
        if let seconds = fileMessageEntity.duration {
            return ThreemaUtilityObjC.timeString(forSeconds: seconds.intValue)
        }
        return "0:00"
    }
}

extension ChatFileAudioMessageCell {
    // MARK: Private functions
    
    private func updateView() {
        let fileMessageEntity = message as! FileMessageEntity
        
        let displayText = ChatFileAudioMessageCell.displayText(fileMessageEntity: fileMessageEntity)
        
        let autoresizingMask: UIView.AutoresizingMask = fileMessageEntity.isOwnMessage ?
            .flexibleLeftMargin : .flexibleRightMargin
        _durationLabel?.autoresizingMask = autoresizingMask
        _audioIcon?.autoresizingMask = autoresizingMask
        _captionLabel?.autoresizingMask = autoresizingMask
        
        if var captionText = fileMessageEntity.caption, !captionText.isEmpty, fileMessageEntity.shouldShowCaption() {
            captionText = TextStyleUtils.makeMentionsString(forText: captionText)
            _captionLabel?.text = captionText
            _captionLabel?.textAlignment = captionText.textAlignment()
            _captionLabel?.isHidden = false
        }
        else {
            _captionLabel?.text = nil
            _captionLabel?.isHidden = true
        }
        
        updateColors()

        setNeedsLayout()
        
        _durationLabel?.text = displayText
    }
    
    private func updateActivityIndicator() {
        let fileMessageEntity = message as! FileMessageEntity
        
        if fileMessageEntity.isOwnMessage {
            if fileMessageEntity.sent.boolValue || (fileMessageEntity.sendFailed?.boolValue ?? false) {
                activityIndicator.stopAnimating()
                _audioIcon?.isHidden = false
            }
            else {
                activityIndicator.startAnimating()
                _audioIcon?.isHidden = true
            }
        }
        else {
            if fileMessageEntity.data != nil {
                activityIndicator.stopAnimating()
                _audioIcon?.isHidden = false
            }
            else {
                if fileMessageEntity.progress != nil {
                    activityIndicator.startAnimating()
                    _audioIcon?.isHidden = true
                }
                else {
                    activityIndicator.stopAnimating()
                    _audioIcon?.isHidden = false
                }
            }
        }
    }
}

extension ChatFileAudioMessageCell {
    // MARK: Override functions
    
    @objc override open class func height(for message: BaseMessage!, forTableWidth tableWidth: CGFloat) -> CGFloat {
        let fileMessageEntity = message as! FileMessageEntity
        
        let text = ChatFileAudioMessageCell.displayText(fileMessageEntity: fileMessageEntity)
        let size = text.sizeOfString(
            maxWidth: ChatFileAudioMessageCell.maxContentWidth(
                forTableWidth: tableWidth,
                isGroup: fileMessageEntity.isGroupMessage
            ) - 25,
            font: ChatFileAudioMessageCell.textFont()
        )
        var cellHeight = CGFloat(ceilf(Float(size.height)))
        
        if let caption = fileMessageEntity.caption, !caption.isEmpty {
            let x: CGFloat = 30.0
            
            let maxSize = CGSize(
                width: ChatFileAudioMessageCell.maxContentWidth(
                    forTableWidth: tableWidth,
                    isGroup: fileMessageEntity.isGroupMessage
                ) - x,
                height: CGFloat.greatestFiniteMagnitude
            )
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
                textSize!.height = textSize!.height + 12.0
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
                let formattedAttributeString = NSMutableAttributedString(
                    attributedString: (dummyLabel!.applyMarkup(for: attributed))!
                )
                dummyLabel?.attributedText = TextStyleUtils.makeMentionsAttributedString(
                    for: formattedAttributeString,
                    textFont: dummyLabel!.font!,
                    at: dummyLabel!.textColor.withAlphaComponent(0.4),
                    messageInfo: Int32(message.isOwn!.intValue),
                    application: UIApplication.shared
                )
                textSize = dummyLabel?.sizeThatFits(maxSize)
                textSize!.height = textSize!.height + 12.0
            }
            cellHeight = cellHeight + textSize!.height
        }
        
        return max(cellHeight, 34.0)
    }
    
    override open func updateColors() {
        super.updateColors()
        _audioIcon?.image = BundleUtil.imageNamed("Microphone")?.withTintColor(Colors.text)
    }
    
    override public func layoutSubviews() {
        guard let fileMessageEntity = message as? FileMessageEntity,
              let conversation = fileMessageEntity.conversation else {
            super.layoutSubviews()
            return
        }

        let x: CGFloat = 30.0

        var captionTextSize = CGSize(width: 0.0, height: 0.0)
        let messageTextWidth: CGFloat = ChatMessageCell.maxContentWidth(
            forTableWidth: safeAreaLayoutGuide.layoutFrame.size.width,
            isGroup: conversation.isGroup()
        )
        
        if let caption = fileMessageEntity.caption, !caption.isEmpty {
            captionTextSize = _captionLabel!.sizeThatFits(
                CGSize(width: messageTextWidth - x, height: CGFloat.greatestFiniteMagnitude)
            )
        }
        let textSize = _durationLabel?.text?.sizeOfString(
            maxWidth: messageTextWidth - 25,
            font: ChatMessageCell.textFont()
        )
        var cellSize = CGSize(
            width: CGFloat(ceilf(Float(max(textSize!.width, captionTextSize.width)))),
            height: CGFloat(ceilf(Float(max(34.0, textSize!.height) + captionTextSize.height)))
        )
        
        if fileMessageEntity.caption == nil {
            cellSize.width = cellSize.width + 25.0
        }
        let size = CGSize(width: cellSize.width, height: cellSize.height)
        setBubbleContentSize(size)
        
        super.layoutSubviews()
        
        var textY: CGFloat = 7.0
        if textSize!.height < 34.0 {
            textY += (34.0 - textSize!.height) / 2
        }
            
        if fileMessageEntity.isOwnMessage {
            _durationLabel?.frame = CGRect(
                x: ceil((msgBackground.frame.origin.x + (size.width / 2)) + 5.0),
                y: textY,
                width: floor(cellSize.width + 1),
                height: floor(textSize!.height + 1)
            )
            _audioIcon!.frame = CGRect(
                x: ceil((msgBackground.frame.origin.x + (size.width / 2)) - _audioIcon!.frame.size.width - 5.0),
                y: (_durationLabel!.frame.origin.y + _durationLabel!.frame.size.height / 2) - _audioIcon!.frame.size
                    .height / 2,
                width: _audioIcon!.frame.size.width,
                height: _audioIcon!.frame.size.height
            )
            resendButton.frame = CGRect(
                x: contentView.frame.size.width - size.width - 160.0 - statusImage.frame.size.width,
                y: 7 + (size.height - 32) / 2,
                width: 114.0,
                height: 32.0
            )
        }
        else {
            _durationLabel?.frame = CGRect(
                x: 46.0 + contentLeftOffset(),
                y: textY,
                width: floor(textSize!.width + 1),
                height: floor(textSize!.height + 1)
            )
            _audioIcon!.frame = CGRect(
                x: 23.0 + contentLeftOffset(),
                y: (_durationLabel!.frame.origin.y + _durationLabel!.frame.size.height / 2) - _audioIcon!.frame.size
                    .height / 2,
                width: _audioIcon!.frame.size.width,
                height: _audioIcon!.frame.size.height
            )
        }
        var originX = msgBackground.frame.origin.x + (x / 2)
        if _captionLabel?.textAlignment == .right {
            originX = msgBackground.frame.origin.x + msgBackground.frame.size.width - (x / 2) - captionTextSize.width
        }
        _captionLabel!.frame = CGRect(
            x: ceil(originX),
            y: ceil(_durationLabel!.frame.origin.y + _durationLabel!.frame.size.height + 3.0),
            width: ceil(captionTextSize.width),
            height: ceil(captionTextSize.height)
        )
        activityIndicator.frame = _audioIcon!.frame
    }
    
    override open func accessibilityLabelForContent() -> String! {
        let fileMessageEntity = message as! FileMessageEntity
        let duration = ThreemaUtilityObjC.accessibilityTimeString(forSeconds: fileMessageEntity.duration?.intValue ?? 0)
        let durationText = "\(BundleUtil.localizedString(forKey: "file_message_voice")), \(duration!)"
        if _captionLabel?.text != nil {
            return "\(durationText). \(_captionLabel!.text!)"
        }
        else {
            return durationText
        }
    }
    
    override open func showActivityIndicator() -> Bool {
        showProgressBar() == false
    }
    
    override open func showProgressBar() -> Bool {
        false
    }
    
    override open func updateProgress() {
        updateActivityIndicator()
    }
        
    override open func messageTapped(_ sender: Any!) {
        let fileMessageEntity = message as! FileMessageEntity
        if fileMessageEntity.data == nil {
            // Not loaded yet. Should we start loading again?
            if fileMessageEntity.progress == nil {
                let loader = BlobMessageLoader()
                loader.start(with: fileMessageEntity, onCompletion: { _ in
                    DDLogInfo("File audio message blob load completed")
                    self.chatVc.fileAudioMessageTapped(fileMessageEntity)
                }) { error in
                    DDLogInfo("File audio message blob load failed with error: \(error!)")
                }
            }
        }
        else {
            chatVc.fileAudioMessageTapped(fileMessageEntity)
        }
    }
    
    override open func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        let fileMessageEntity = message as! FileMessageEntity
        if action == #selector(resendMessage(_:)), fileMessageEntity.isOwnMessage,
           fileMessageEntity.sendFailed?.boolValue ?? false {
            return true
        }
        else if action == #selector(deleteMessage(_:)), fileMessageEntity.isOwnMessage,
                !fileMessageEntity.sent.boolValue,
                !(fileMessageEntity.sendFailed?.boolValue ?? false) {
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
        else if action == #selector(copyMessage(_:)), _captionLabel?.text == nil {
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
            UIPasteboard.general.string = caption
        }
    }
    
    override open func textForQuote() -> String! {
        _captionLabel?.text as? String ?? ""
    }
        
    override open func performPlayActionForAccessibility() -> Bool {
        messageTapped(self)
        return true
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
    
    override open func getContextMenu(_ indexPath: IndexPath!, point: CGPoint) -> UIContextMenuConfiguration! {
        if isEditing == true {
            return nil
        }
        
        // returns nil if there is no link tapped
        if let menu = contextMenuForLink(indexPath, point: point) {
            return menu
        }
        
        return super.getContextMenu(indexPath, point: point)
    }
}

extension ChatFileAudioMessageCell {
    // MARK: Public functions
    
    func setBaseMessage(newMessage: BaseMessage) {
        super.message = newMessage
        
        updateView()
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

extension String {
    func sizeOfString(maxWidth: CGFloat, font: UIFont) -> CGSize {
        let tmp = NSMutableAttributedString(string: self, attributes: [NSAttributedString.Key.font: font])
        let limitSize = CGSize(width: maxWidth, height: CGFloat(MAXFLOAT))
        let contentSize = tmp.boundingRect(with: limitSize, options: .usesLineFragmentOrigin, context: nil)
        return contentSize.size
    }
}
