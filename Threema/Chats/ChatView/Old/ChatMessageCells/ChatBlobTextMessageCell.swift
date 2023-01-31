//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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

@objc open class ChatBlobTextMessageCell: ChatBlobMessageCell, ZSWTappableLabelTapDelegate,
    ZSWTappableLabelLongPressDelegate {
    internal var _captionLabel: ZSWTappableLabel?
    
    override open var accessibilityCustomActions: [UIAccessibilityCustomAction]? {
        get {
            getAccessibilityCustomActions()
        }
        set {
            super.accessibilityCustomActions = newValue
        }
    }
    
    private let canOpenPhoneLinks = UIApplication.shared.canOpenURL(URL(string: "tel:0")!)
    
    override public init!(style: UITableViewCell.CellStyle, reuseIdentifier: String!, transparent: Bool) {
        super.init(style: style, reuseIdentifier: reuseIdentifier, transparent: transparent)
        self.isAccessibilityElement = true
    }
    
    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func tappableLabel(
        _ tappableLabel: ZSWTappableLabel,
        tappedAt idx: Int,
        withAttributes attributes: [NSAttributedString.Key: Any] = [:]
    ) {
        if let attribute = attributes[NSAttributedString.Key(rawValue: "NSTextCheckingResult")] {
            handleTapResult(result: attribute)
        }
    }
    
    public func tappableLabel(
        _ tappableLabel: ZSWTappableLabel,
        longPressedAt idx: Int,
        withAttributes attributes: [NSAttributedString.Key: Any] = [:]
    ) {
        if let attribute = attributes[NSAttributedString.Key(rawValue: "NSTextCheckingResult")] {
            handleLongPressResult(result: attribute)
        }
    }
    
    override open func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if isEditing {
            return self
        }
        return super.hitTest(point, with: event)
    }
    
    override open func previewViewController(
        for previewingContext: UIViewControllerPreviewing!,
        viewControllerForLocation location: CGPoint
    ) -> UIViewController! {
        guard let regionInfo = _captionLabel?.tappableRegionInfo(
            forPreviewingContext: previewingContext,
            location: location
        ) else {
            return nil
        }

        let result = regionInfo.attributes[NSAttributedString.Key(rawValue: "NSTextCheckingResult")]
        if result.self is NSTextCheckingResult {
            let checkingResult = result as! NSTextCheckingResult
            if checkingResult.url != nil, checkingResult.resultType == .link,
               !checkingResult.url!.absoluteString.hasPrefix("mailto:") {
                let url = checkingResult.url
                if url?.scheme == "http" || url?.scheme == "https" {
                    regionInfo.configure(previewingContext: previewingContext)
                    let safari = ThreemaSafariViewController(url: url!)
                    safari.url = url!
                    return safari
                }
            }
        }
        return nil
    }
    
    /// Retun a menu if tapped object was a link.
    /// Will return nil if nothing was found
    open func contextMenuForLink(_ indexPath: IndexPath!, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let convertedPoint = _captionLabel?.convert(point, from: chatVc.chatContent) else {
            return nil
        }
        if let regionInfo = _captionLabel?.checkIsPointAction(convertedPoint) {
            if let checkingResult =
                regionInfo[NSAttributedString.Key(rawValue: "NSTextCheckingResult")] as? NSTextCheckingResult {
                if checkingResult.url != nil, checkingResult.resultType == .link,
                   !checkingResult.url!.absoluteString.hasPrefix("mailto:") {
                    guard let url = checkingResult.url else {
                        return nil
                    }
                    
                    if url.scheme == "http" || url.scheme == "https" {
                        let safariViewController = ThreemaSafariViewController(url: url)
                        safariViewController.url = url
                        return UIContextMenuConfiguration(
                            identifier: indexPath as NSCopying?,
                            previewProvider: { () -> UIViewController? in
                                safariViewController
                            }
                        ) { _ -> UIMenu? in
                            var menuItems = [UIAction]()
                            let copyImage = UIImage(systemName: "doc.on.doc.fill", compatibleWith: self.traitCollection)
                            let action = UIAction(
                                title: BundleUtil.localizedString(forKey: "copy"),
                                image: copyImage,
                                identifier: nil,
                                discoverabilityTitle: nil,
                                attributes: [],
                                state: .off
                            ) { _ in
                                UIPasteboard.general.string = self.displayString(for: url)
                            }
                            menuItems.append(action)
                            return UIMenu(
                                title: "",
                                image: nil,
                                identifier: .application,
                                options: .displayInline,
                                children: menuItems
                            )
                        }
                    }
                }
            }
        }
        return nil
    }
    
    open class func calculateCaptionHeight(scaledSize: CGSize, fileMessageEntity: FileMessageEntity) -> CGFloat {
        let imageInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        
        if let caption = fileMessageEntity.caption, !caption.isEmpty {
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
                    messageInfo: Int32(fileMessageEntity.isOwn!.intValue),
                    application: UIApplication.shared
                )
                textSize = dummyLabel?.sizeThatFits(maxSize)
                textSize!.height = textSize!.height + 23.0
            }
            return textSize!.height
        }
        else {
            return imageInsets.top + imageInsets.bottom
        }
    }
}

extension ChatBlobTextMessageCell {
    // MARK: Private functions
    
    private func handleTapResult(result: Any) {
        if result.self is Contact {
            chatVc.mentionTapped(result)
        }
        else if result.self is NSString || result.self is String {
            let resultString = result as! String
            
            if resultString == "meContact" {
                chatVc.mentionTapped(resultString)
            }
        }
        else if result.self is NSTextCheckingResult {
            openLink(with: result as! NSTextCheckingResult)
        }
    }
    
    @objc private func openLink(with urlResult: NSTextCheckingResult) {
        if urlResult.resultType == .link {
            IDNSafetyHelper.safeOpen(url: urlResult.url!, viewController: chatVc)
        }
        else if urlResult.resultType == .phoneNumber {
            callPhoneNumber(phoneNumber: urlResult.phoneNumber!)
        }
    }
    
    private func callPhoneNumber(phoneNumber: String) {
        let cleanString = phoneNumber.replacingOccurrences(of: "\u{00a0}", with: "")

        if let url =
            URL(string: String(
                format: "tel:%@",
                cleanString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
            )) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    private func handleLongPressResult(result: Any) {
        if result.self is NSString || result.self is String {
            return
        }
        else if result.self is Contact {
            chatVc.mentionTapped(result)
        }
        else if result.self is NSTextCheckingResult {
            let checkingResult = result as! NSTextCheckingResult
            
            if checkingResult.resultType == .link {
                if let actionURL = checkingResult.url {
                    let actionSheet = NonFirstResponderActionSheet(
                        title: displayString(for: actionURL),
                        message: nil,
                        preferredStyle: .actionSheet
                    )
                    actionSheet
                        .addAction(UIAlertAction(
                            title: BundleUtil.localizedString(forKey: "open"),
                            style: .default,
                            handler: { _ in
                                IDNSafetyHelper.safeOpen(url: actionURL, viewController: self.chatVc)
                            }
                        ))
                    actionSheet
                        .addAction(UIAlertAction(
                            title: BundleUtil.localizedString(forKey: "copy"),
                            style: .default,
                            handler: { _ in
                                UIPasteboard.general.string = self.displayString(for: actionURL)
                            }
                        ))
                    actionSheet
                        .addAction(UIAlertAction(
                            title: BundleUtil.localizedString(forKey: "cancel"),
                            style: .cancel,
                            handler: nil
                        ))
                    
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        actionSheet.popoverPresentationController?.sourceView = self
                        actionSheet.popoverPresentationController?.sourceRect = bounds
                    }
                    
                    chatVc.chatBar.resignFirstResponder()
                    chatVc.present(actionSheet, animated: true, completion: nil)
                }
            }
            else if checkingResult.resultType == .phoneNumber {
                if let actionPhone = checkingResult.phoneNumber {
                    let actionSheet = NonFirstResponderActionSheet(
                        title: actionPhone,
                        message: nil,
                        preferredStyle: .actionSheet
                    )
                    actionSheet
                        .addAction(UIAlertAction(
                            title: BundleUtil.localizedString(forKey: "call"),
                            style: .default,
                            handler: { _ in
                                self.callPhoneNumber(phoneNumber: actionPhone)
                            }
                        ))
                    actionSheet
                        .addAction(UIAlertAction(
                            title: BundleUtil.localizedString(forKey: "copy"),
                            style: .default,
                            handler: { _ in
                                UIPasteboard.general.string = actionPhone
                            }
                        ))
                    actionSheet
                        .addAction(UIAlertAction(
                            title: BundleUtil.localizedString(forKey: "cancel"),
                            style: .cancel,
                            handler: nil
                        ))
                    
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        actionSheet.popoverPresentationController?.sourceView = self
                        actionSheet.popoverPresentationController?.sourceRect = bounds
                    }
                    
                    chatVc.chatBar.resignFirstResponder()
                    chatVc.present(actionSheet, animated: true, completion: nil)
                }
            }
        }
    }
    
    private func displayString(for url: URL) -> String {
        url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
    }
    
    private func getAccessibilityCustomActions() -> [UIAccessibilityCustomAction] {
        if _captionLabel == nil {
            return []
        }
        if _captionLabel!.accessibilityElements == nil {
            return []
        }
        
        var actions = super.accessibilityCustomActions
        var indexCounter = 0
        
        if _captionLabel!.accessibilityElementCount() > 0 {
            for i in 0..._captionLabel!.accessibilityElementCount() - 1 {
                if let element = _captionLabel!.accessibilityElement(at: i) as? UIAccessibilityElement {
                    if element.accessibilityLabel != nil, element.accessibilityLabel! != ".",
                       element.accessibilityLabel! != "@" {
                        if checkTextResult(text: element.accessibilityLabel!) != nil {
                            let openString =
                                "\(BundleUtil.localizedString(forKey: "open")): \(element.accessibilityLabel!)"

                            let linkAction = UIAccessibilityCustomAction(name: openString) { _ in
                                self.handleTapResult(result: self.checkTextResult(text: element.accessibilityLabel!)!)
                                return true
                            }
                            actions?.insert(linkAction, at: indexCounter)
                            indexCounter += 1
                            
                            let shareString =
                                "\(BundleUtil.localizedString(forKey: "share")): \(element.accessibilityLabel!)"
                            let shareAction = UIAccessibilityCustomAction(
                                name: shareString,
                                target: self,
                                selector: #selector(shareLink)
                            )
                            actions?.insert(shareAction, at: indexCounter)
                            indexCounter += 1
                        }
                        else {
                            let mentionString =
                                "\(BundleUtil.localizedString(forKey: "details")): \(element.accessibilityLabel!)"
                            let mentionAction = UIAccessibilityCustomAction(
                                name: mentionString,
                                target: self,
                                selector: #selector(openMentions(action:))
                            )
                            actions?.insert(mentionAction, at: indexCounter)
                            indexCounter += 1
                        }
                    }
                }
            }
        }
        
        return actions!
    }
    
    @objc private func shareLink(action: UIAccessibilityCustomAction) -> Bool {
        let urlResult = checkTextResult(text: action.name)
        
        if urlResult?.resultType == .link {
            let activityViewController = ActivityUtil.activityViewController(
                withActivityItems: [urlResult!.url ?? ""],
                applicationActivities: []
            )
            chatVc.present(activityViewController, animated: true, from: self)
        }
        else if urlResult?.resultType == .phoneNumber {
            let activityViewController = ActivityUtil.activityViewController(
                withActivityItems: [urlResult!.phoneNumber ?? ""],
                applicationActivities: []
            )
            chatVc.present(activityViewController, animated: true, from: self)
        }
        
        return true
    }

    private func checkTextResult(text: String) -> NSTextCheckingResult? {
        var textCheckingTypes: NSTextCheckingTypes = NSTextCheckingResult.CheckingType.link.rawValue
        
        if canOpenPhoneLinks {
            textCheckingTypes |= NSTextCheckingResult.CheckingType.phoneNumber.rawValue
        }
        
        var urlResult: NSTextCheckingResult?
        let detector = try! NSDataDetector(types: textCheckingTypes)
        detector
            .enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: text.count)) { result, _, _ in
                urlResult = result
            }
        return urlResult
    }
    
    @objc private func openMentions(action: UIAccessibilityCustomAction) -> Bool {
        let identity = action.name.replacingOccurrences(
            of: "\(BundleUtil.localizedString(forKey: "details")) @",
            with: ""
        )
        if identity == BundleUtil.localizedString(forKey: "me") {
            handleTapResult(result: "meContact")
        }
        else {
            if let contact = ContactStore.shared().contact(for: identity) {
                handleTapResult(result: contact)
            }
        }
        return true
    }
}
