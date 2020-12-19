//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2020 Threema GmbH
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
import UIKit
import CocoaLumberjackSwift

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

        _audioIcon = UIImageView.init(image: BundleUtil.imageNamed("Microphone"))
        contentView.addSubview(_audioIcon!)
        
        _durationLabel = UILabel.init()
        _durationLabel?.clearsContextBeforeDrawing = false
        _durationLabel?.backgroundColor = .clear
        _durationLabel?.numberOfLines = 0
        _durationLabel?.lineBreakMode = .byWordWrapping
        _durationLabel?.font = ChatFileAudioMessageCell.textFont()
        contentView.addSubview(_durationLabel!)
        
        _captionLabel = ChatTextMessageCell.makeAttributedLabel(withFrame: self.bounds)
        _captionLabel?.tapDelegate = self
        _captionLabel?.longPressDelegate = self
        contentView.addSubview(_captionLabel!)


        if #available(iOS 11.0, *) {
            _audioIcon?.accessibilityIgnoresInvertColors = true
        }
        
        setupColors()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public class func displayText(fileMessage: FileMessage) -> String {
        if let seconds = fileMessage.getDuration() {
            return Utils.timeString(forSeconds: seconds.intValue)
        }
        return "0:00"
    }
}

extension ChatFileAudioMessageCell {
    // MARK: Private functions
    
    private func updateView() {
        let fileMessage = message as! FileMessage
        
        let displayText = ChatFileAudioMessageCell.displayText(fileMessage: fileMessage)
        
        let autoresizingMask: UIView.AutoresizingMask = fileMessage.isOwn.boolValue ? .flexibleLeftMargin : .flexibleRightMargin
        _durationLabel?.autoresizingMask = autoresizingMask
        _audioIcon?.autoresizingMask = autoresizingMask
        _captionLabel?.autoresizingMask = autoresizingMask
        
        if var captionText = fileMessage.getCaption(), captionText.count > 0, fileMessage.shouldShowCaption() {
            captionText = TextStyleUtils.makeMentionsString(forText: captionText)
            _captionLabel?.text = captionText
            _captionLabel?.isHidden = false
        }
        else {
            _captionLabel?.text = nil
            _captionLabel?.isHidden = true
        }
        
        setupColors()

        setNeedsLayout()
        
        _durationLabel?.text = displayText
    }
    
    private func updateActivityIndicator() {
        let fileMessage = message as! FileMessage
        
        if fileMessage.isOwn != nil, fileMessage.isOwn.boolValue {
            if fileMessage.sent.boolValue || fileMessage.sendFailed.boolValue {
                activityIndicator.stopAnimating()
                _audioIcon?.isHidden = false
            } else {
                activityIndicator.startAnimating()
                _audioIcon?.isHidden = true
            }
        } else {
            if fileMessage.data != nil {
                activityIndicator.stopAnimating()
                _audioIcon?.isHidden = false
            } else {
                if fileMessage.progress != nil {
                    activityIndicator.startAnimating()
                    _audioIcon?.isHidden = true
                } else {
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
        let fileMessage = message as! FileMessage
        
        let text = ChatFileAudioMessageCell.displayText(fileMessage: fileMessage)
        let size = text.sizeOfString(maxWidth: ChatFileAudioMessageCell.maxContentWidth(forTableWidth: tableWidth) - 25, font: ChatFileAudioMessageCell.textFont())
        var cellHeight = CGFloat(ceilf(Float(size.height)))
        
        if let caption = fileMessage.getCaption(), caption.count > 0 {
            let x: CGFloat = 30.0
            
            let maxSize = CGSize.init(width: ChatFileAudioMessageCell.maxContentWidth(forTableWidth: tableWidth) - x, height: CGFloat.greatestFiniteMagnitude)
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
                textSize!.height = textSize!.height + 12.0
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
                textSize!.height = textSize!.height  + 12.0

            }
            cellHeight = cellHeight + textSize!.height
        }
        
        return max(cellHeight, 34.0)
    }
    
    override open func setupColors() {
        super.setupColors()
        if #available(iOS 13.0, *) {
            _audioIcon?.image = BundleUtil.imageNamed("Microphone")?.withTintColor(Colors.fontNormal())
        } else {
            _audioIcon?.image = BundleUtil.imageNamed("Microphone")?.withTint(Colors.fontNormal())
        }
        _durationLabel?.textColor = Colors.fontNormal()
        _captionLabel?.textColor = Colors.fontNormal()
    }
    
    override public func layoutSubviews() {
        let fileMessage = message as! FileMessage
        let x: CGFloat = 30.0

        var messageTextWidth: CGFloat = 0.0
        var captionTextSize: CGSize = CGSize.init(width: 0.0, height: 0.0)
        if #available(iOS 11.0, *) {
            messageTextWidth = ChatMessageCell.maxContentWidth(forTableWidth: safeAreaLayoutGuide.layoutFrame.size.width)
        } else {
            messageTextWidth = ChatMessageCell.maxContentWidth(forTableWidth: frame.size.width)
        }
        
        if let caption = fileMessage.getCaption(), caption.count > 0 {
            captionTextSize = _captionLabel!.sizeThatFits(CGSize.init(width: messageTextWidth - x, height: CGFloat.greatestFiniteMagnitude))
        }
        let textSize = _durationLabel?.text?.sizeOfString(maxWidth: messageTextWidth - 25, font: ChatMessageCell.textFont())
        var cellSize = CGSize.init(width: CGFloat(ceilf(Float(max(textSize!.width, captionTextSize.width)))), height: CGFloat(ceilf(Float(max(34.0, textSize!.height) + captionTextSize.height))))
        
        if fileMessage.getCaption() == nil {
            cellSize.width = cellSize.width + 25.0
        }
        let size = CGSize.init(width: cellSize.width, height: cellSize.height)
        setBubbleContentSize(size)
        
        super.layoutSubviews()
        
        var  textY: CGFloat = 7.0
        if textSize!.height < 34.0 {
            textY += (34.0 - textSize!.height) / 2;
        }
            
        if fileMessage.isOwn != nil, fileMessage.isOwn.boolValue {
            _durationLabel?.frame = CGRect.init(x: ceil((msgBackground.frame.origin.x + (size.width / 2)) + 5.0), y: textY, width: floor(cellSize.width + 1), height: floor(textSize!.height + 1))
            _audioIcon!.frame = CGRect.init(x: ceil((msgBackground.frame.origin.x + (size.width / 2)) - _audioIcon!.frame.size.width - 5.0), y: (_durationLabel!.frame.origin.y + _durationLabel!.frame.size.height/2) - _audioIcon!.frame.size.height / 2, width: _audioIcon!.frame.size.width, height: _audioIcon!.frame.size.height)
            resendButton.frame = CGRect.init(x: contentView.frame.size.width - size.width - 160.0 - statusImage.frame.size.width, y: 7 + (size.height - 32) / 2, width: 114.0, height: 32.0)
        } else {
            _durationLabel?.frame = CGRect.init(x: 46.0 + contentLeftOffset(), y: textY, width: floor(textSize!.width + 1), height: floor(textSize!.height + 1))
            _audioIcon!.frame = CGRect.init(x: 23.0 + contentLeftOffset(), y: (_durationLabel!.frame.origin.y + _durationLabel!.frame.size.height/2) - _audioIcon!.frame.size.height / 2, width: _audioIcon!.frame.size.width, height: _audioIcon!.frame.size.height)
        }
        _captionLabel!.frame  = CGRect.init(x:ceil(msgBackground.frame.origin.x + (x/2)), y: ceil(_durationLabel!.frame.origin.y + _durationLabel!.frame.size.height + 3.0), width: ceil(captionTextSize.width), height: ceil(captionTextSize.height))
        activityIndicator.frame = _audioIcon!.frame
    }
    
    override open func accessibilityLabelForContent() -> String! {
        let fileMessage = message as! FileMessage
        let duration = Utils.accessabilityTimeString(forSeconds: fileMessage.getDuration()!.intValue)
        let durationText = "\(BundleUtil.localizedString(forKey: "audio") ?? "Audio"), \(duration!)"
        if _captionLabel?.text != nil {
            return "\(durationText). \(_captionLabel!.text!)"
        } else {
            return durationText
        }
    }
    
    override open func showActivityIndicator() -> Bool {
        return showProgressBar() == false
    }
    
    override open func showProgressBar() -> Bool {
        return false
    }
    
    override open func updateProgress() {
        updateActivityIndicator()
    }
        
    override open func messageTapped(_ sender: Any!) {
        let fileMessage = message as! FileMessage
        if fileMessage.data == nil {
            // Not loaded yet. Should we start loading again?
            if fileMessage.progress == nil {
                let loader: BlobMessageLoader = BlobMessageLoader.init()
                loader.start(with: fileMessage, onCompletion: { (baseMessage) in
                    DDLogInfo("File audio message blob load completed")
                }) { (error) in
                    DDLogInfo("File audio message blob load failed with error: \(error!)")
                }
            }
        }
        chatVc.fileAudioMessageTapped(fileMessage)
    }
    
    override open func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        let fileMessage = message as! FileMessage
        if action == #selector(resendMessage(_:)) && fileMessage.isOwn.boolValue && fileMessage.sendFailed.boolValue {
            return true
        }
        else if action == #selector(deleteMessage(_:)) && fileMessage.isOwn.boolValue && !fileMessage.sent.boolValue && !fileMessage.sendFailed.boolValue {
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
        else if action == #selector(copyMessage(_:)) && _captionLabel?.text == nil {
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
        if let caption = fileMessage.getCaption(), caption.count > 0 {
            UIPasteboard.general.string = fileMessage.getCaption()
        }
    }
    
    open override func textForQuote() -> String! {
        return (_captionLabel?.text as? String ?? "")
    }
        
    open override func performPlayActionForAccessibility() -> Bool {
        messageTapped(self)
        return true
    }
    
    open override func previewViewController(for previewingContext: UIViewControllerPreviewing!, viewControllerForLocation location: CGPoint) -> UIViewController! {
        if let controller = super.previewViewController(for: previewingContext, viewControllerForLocation: location) {
            return controller
        }
        return chatVc.headerView.getPhotoBrowser(at: message, forPeeking: true)
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
        
        return super.getContextMenu(indexPath, point: point)
    }
}

extension ChatFileAudioMessageCell {
    // MARK: Public functions
    
    func setBaseMessage(newMessage: BaseMessage) {
        super.message = newMessage
        
        self.updateView()
    }
    
    @objc func resendMessage(_ menuController: UIMenuController) {
        let fileMessage = message as! FileMessage
        let sender: FileMessageSender = FileMessageSender.init()
        sender.retryMessage(fileMessage)
    }
    
    @objc func speakMessage(_ menuController: UIMenuController) {
        if _captionLabel?.text != nil {
            let speakText = "\(BundleUtil.localizedString(forKey: "image") ?? "Image"). \(_captionLabel!.text!)"
            let utterance: AVSpeechUtterance = AVSpeechUtterance.init(string: speakText)
            let syn = AVSpeechSynthesizer.init()
            syn.speak(utterance)
        }
    }
}

extension String {
    func sizeOfString(maxWidth:CGFloat, font: UIFont) -> CGSize {
        let tmp = NSMutableAttributedString(string: self, attributes:[NSAttributedString.Key.font:font])
        let limitSize = CGSize(width: maxWidth, height: CGFloat(MAXFLOAT))
        let contentSize = tmp.boundingRect(with: limitSize, options: .usesLineFragmentOrigin, context: nil)
        return contentSize.size
    }
}
