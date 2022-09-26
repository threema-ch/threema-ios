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

@objc public protocol OEMentionsHelperDelegate: AnyObject {
    func mentionSelected(id: Int, name: String)
    func textView(_ growingTextView: HPGrowingTextView!, willChangeHeight height: Float)
    func textView(
        _ growingTextView: HPGrowingTextView!,
        shouldChangeTextIn range: NSRange,
        replacementText text: String!
    ) -> Bool
    func textViewDidChange(_ growingTextView: HPGrowingTextView!)
}

@objc public class OEMentionsHelper: NSObject {
    
    @objc open weak var delegate: OEMentionsHelperDelegate?
    private var oementions: OEMentions
    private var growingTextView: HPGrowingTextView
    private var topLine: UIView
    private var mainView: UIView
    
    private let regex = "@\\[[0-9A-Z*@]{8}\\]"
    private var mentionCountBeforeChange = 0
    private var shouldUpdateTextColor = false
    private var isDictationRunning = false
    
    @objc public required init(
        containerView: UIView,
        chatInputView: HPGrowingTextView,
        mainView: UIView,
        sortedContacts: [Contact]
    ) {
        let memberlist = OEMentionsHelper.buildOeObjectsList(sortedContacts: sortedContacts)
        self.growingTextView = chatInputView
        self.mainView = mainView
        self.oementions = OEMentions(
            containerView: containerView,
            textView: chatInputView.internalTextView,
            mainView: mainView,
            oeObjects: memberlist
        )
        self.topLine = UIView()
        topLine.frame.size.height = 1
        topLine.backgroundColor = Colors.hairLine
        topLine.isHidden = true
        mainView.insertSubview(topLine, aboveSubview: oementions.tableView)
        super.init()
        oementions.delegate = self
        chatInputView.delegate = self
        oementions.nameFont = chatInputView.internalTextView.font!
        updateColors()
        oementions.showMentionFullInContainer = false
        oementions.tableView.addObserver(self, forKeyPath: "hidden", options: [.new], context: nil)
    }
        
    @objc public func updateColors() {
        oementions.nameColor = Colors.textLight
        oementions.notMentionColor = growingTextView.internalTextView.textColor!
        oementions.changeMentionTableviewBackground(color: Colors.backgroundTableViewCell)
        oementions.changeMentionTableviewSeparatorColor(color: Colors.hairLine)
        updateTextColor()
    }
    
    @objc public func formattedMentionText() -> String {
        var textViewText = growingTextView.internalTextView.text
        var difference = 0
        if !oementions.mentionsIndexes.isEmpty {
            let mentionsIndexes = oementions.mentionsIndexes.sorted(by: { $0.0 < $1.0 })
            for (index, dict) in mentionsIndexes {
                let length = dict["length"] as! Int
                
                let key = dict["key"] as! String
                let nsRange = NSMakeRange(index + difference, length)
                let range = Range(nsRange, in: textViewText!)
                textViewText?.replaceSubrange(range!, with: key)
                
                let nameCount = length
                let replaceCount = key.count
                difference = difference + (replaceCount - nameCount)
            }
        }
        return textViewText!
    }
    
    @objc public func addMentions(draft: String) {
        var draftString = draft

        do {
            let mentionRegex = try NSRegularExpression(pattern: regex, options: .caseInsensitive)
            
            var finished = false
            var lastNotFoundIndex = -1
            
            while !finished {
                let mentionResult = mentionRegex.matches(
                    in: draftString,
                    options: .reportCompletion,
                    range: NSRange(location: 0, length: draftString.utf16.count)
                )
                
                var result: NSTextCheckingResult?
                if lastNotFoundIndex == -1 {
                    result = mentionResult.first
                }
                else {
                    if mentionResult.count >= lastNotFoundIndex + 2 {
                        result = mentionResult[lastNotFoundIndex + 1]
                    }
                }
                
                if result == nil {
                    finished = true
                    break
                }
                
                let mentionTag =
                    String(draftString[
                        String.Index(utf16Offset: result!.range.location, in: draftString)...String
                            .Index(
                                utf16Offset: result!.range.location + result!.range.length - 1,
                                in: draftString
                            )
                    ])
                if mentionTag.count == 11 {
                    let identity =
                        String(mentionTag[
                            String.Index(utf16Offset: 2, in: mentionTag)...String
                                .Index(utf16Offset: 9, in: mentionTag)
                        ]).uppercased()
                    let contact = ContactStore.shared().contact(for: identity)
                    
                    if contact != nil || identity == MyIdentityStore.shared()?.identity || identity == "@@@@@@@@" {
                        var displayName = BundleUtil.localizedString(forKey: "me")
                        
                        if let nickname = MyIdentityStore.shared().pushFromName {
                            if !nickname.utf16.isEmpty {
                                displayName = nickname
                            }
                        }
                        
                        if contact != nil {
                            displayName = contact!.mentionName
                        }
                        else if identity == "@@@@@@@@" {
                            displayName = BundleUtil.localizedString(forKey: "mentions_all")
                        }
                        
                        let range = Range(result!.range, in: draftString)
                        draftString = draftString.replacingCharacters(in: range!, with: "@\(displayName)")
                        
                        let dict = ["key": mentionTag, "length": displayName.utf16.count + 1] as [String: Any]
                        oementions.mentionsIndexes[result!.range.location] = dict
                    }
                    else {
                        let range = Range(result!.range, in: draftString)
                        draftString = draftString.replacingCharacters(in: range!, with: "@\(identity)")
                        if lastNotFoundIndex == -1 {
                            lastNotFoundIndex = 0
                        }
                        else {
                            lastNotFoundIndex += 1
                        }
                    }
                }
                else {
                    if lastNotFoundIndex == -1 {
                        lastNotFoundIndex = 0
                    }
                    else {
                        lastNotFoundIndex += 1
                    }
                }
            }
            growingTextView.text = draftString
            updateTextColor()
        }
        catch {
            print("failed regex draft for mentions")
        }
    }
    
    @objc public func resetMentionsIndexes() {
        oementions.mentionsIndexes.removeAll()
    }
    
    @objc public func updateContainterViewFrame() {
        // add space on top of input view
        oementions.textViewHeight = growingTextView.frame.size.height + 3.0
        oementions.updatePosition()
        topLine.frame = CGRect(
            x: oementions.tableView.frame.origin.x,
            y: oementions.tableView.frame.origin.y - 1,
            width: oementions.tableView.frame.size.width,
            height: 1
        )
    }

    @objc public func updateTextColor() {
        if !isDictationRunning,
           growingTextView.internalTextView.markedTextRange == nil {
            var attributes = [NSAttributedString.Key: AnyObject]()
            attributes[.foregroundColor] = oementions.notMentionColor
            attributes[.font] = oementions.nameFont
            if !oementions.mentionsIndexes.isEmpty {
                let attributedString = NSMutableAttributedString(
                    string: oementions.textView!.text,
                    attributes: attributes
                )
                
                let mentionsIndexes = oementions.mentionsIndexes.sorted(by: { $0.0 < $1.0 })
                for (index, dict) in mentionsIndexes {
                    let length = dict["length"] as! Int
                    attributedString.addAttribute(
                        NSAttributedString.Key.foregroundColor,
                        value: oementions.nameColor,
                        range: NSMakeRange(index, length)
                    )
                    attributedString.addAttribute(
                        NSAttributedString.Key.font,
                        value: oementions.nameFont,
                        range: NSMakeRange(index, length)
                    )
                    attributedString.addAttribute(
                        NSAttributedString.Key.foregroundColor,
                        value: Colors.textLink,
                        range: NSMakeRange(index, length)
                    )
                }
                
                if let selectedRange = oementions.textView!.selectedTextRange {
                    oementions.textView!.attributedText = attributedString
                    // and only if the new position is valid
                    if let newPosition = oementions.textView!.position(
                        from: selectedRange.start,
                        in: UITextLayoutDirection.left,
                        offset: 0
                    ) {
                        // set the new position
                        oementions.textView!.selectedTextRange = oementions.textView!.textRange(
                            from: newPosition,
                            to: newPosition
                        )
                    }
                }
                else {
                    oementions.textView!.attributedText = attributedString
                }
            }
            else {
                if let selectedRange = oementions.textView!.selectedTextRange {
                    oementions.textView!.attributedText = NSMutableAttributedString(
                        string: oementions.textView!.text,
                        attributes: attributes
                    )
                    // and only if the new position is valid
                    if let newPosition = oementions.textView!.position(
                        from: selectedRange.start,
                        in: UITextLayoutDirection.left,
                        offset: 0
                    ) {
                        // set the new position
                        oementions.textView!.selectedTextRange = oementions.textView!.textRange(
                            from: newPosition,
                            to: newPosition
                        )
                    }
                }
                else {
                    oementions.textView!.attributedText = NSMutableAttributedString(
                        string: oementions.textView!.text,
                        attributes: attributes
                    )
                }
            }
        }
    }
    
    @objc public func updateOeObjects(sortedContacts: [Contact]) {
        oementions.setOeObjects(oeObjects: OEMentionsHelper.buildOeObjectsList(sortedContacts: sortedContacts))
    }
    
    class func buildOeObjectsList(sortedContacts: [Contact]) -> [OEObject] {
        var memberlist = [OEObject]()
        // add @all contact
        let oeObject = OEObject(
            id: 0,
            name: "@" + BundleUtil.localizedString(forKey: "all"),
            key: "@[@@@@@@@@]",
            object: nil
        )
        memberlist.append(oeObject)
        
        var i = 1
        for contact in sortedContacts {
            let oeObject = OEObject(
                id: i,
                name: "@" + contact.displayName,
                key: "@[\(contact.identity)]",
                object: contact
            )
            memberlist.append(oeObject)
            i += 1
        }
        return memberlist
    }
    
    override public func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        let tableView = object as! UITableView
        topLine.isHidden = tableView.isHidden
    }
    
    private func startKeyboardObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(changeInputMode),
            name: UITextInputMode.currentInputModeDidChangeNotification,
            object: nil
        )
    }
    
    private func stopKeyboardObserver() {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func changeInputMode(notification: NSNotification) {
        let inputMethod = growingTextView.textInputMode?.primaryLanguage
        if inputMethod == "dictation" {
            isDictationRunning = true
        }
        else {
            isDictationRunning = false
        }
    }
}

// MARK: - HPGrowingTextViewDelegate

extension OEMentionsHelper: HPGrowingTextViewDelegate {
    
    public func growingTextViewDidBeginEditing(_ growingTextView: HPGrowingTextView!) {
        startKeyboardObserver()
    }

    public func growingTextView(_ growingTextView: HPGrowingTextView!, willChangeHeight height: Float) {
        delegate?.textView(growingTextView, willChangeHeight: height)
    }
    
    public func growingTextView(_ growingTextView: HPGrowingTextView!, didChangeHeight height: Float) {
        updateContainterViewFrame()
    }
    
    public func growingTextView(
        _ growingTextView: HPGrowingTextView!,
        shouldChangeTextIn range: NSRange,
        replacementText text: String!
    ) -> Bool {
        mentionCountBeforeChange = oementions.mentionsIndexes.count
        _ = oementions.textView(growingTextView.internalTextView, shouldChangeTextIn: range, replacementText: text)
        return delegate?.textView(growingTextView, shouldChangeTextIn: range, replacementText: text) ?? true
    }
    
    public func growingTextViewDidChange(_ growingTextView: HPGrowingTextView!) {
        if growingTextView.internalTextView.isFirstResponder {
            oementions.updatePosition()
        }

        if shouldUpdateTextColor == true ||
            (mentionCountBeforeChange > oementions.mentionsIndexes.count && oementions.mentionsIndexes.isEmpty) {
            shouldUpdateTextColor = false
            updateTextColor()
        }

        delegate?.textViewDidChange(growingTextView)
    }
    
    public func growingTextViewDidEndEditing(_ growingTextView: HPGrowingTextView!) {
        stopKeyboardObserver()
        oementions.textViewDidEndEditing(growingTextView.internalTextView)
    }
}

// MARK: - OEMentionsDelegate

extension OEMentionsHelper: OEMentionsDelegate {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath, oeObject: OEObject) -> UITableViewCell {
        let cell = MentionCell(style: UITableViewCell.CellStyle.default, reuseIdentifier: "MentionCell")
        cell.backgroundColor = UIColor.clear
        cell.selectionStyle = UITableViewCell.SelectionStyle.none
        if let contact = oeObject.object as? Contact {
            cell.contact = contact
        }
        else {
            // @all contact
            cell.allContact = true
        }
        return cell
    }
    
    func mentionSelected(id: Int, name: String) {
        delegate?.mentionSelected(id: id, name: name)
        growingTextView.refreshHeight()
        updateTextColor()
    }
    
    func tableViewPositionUpdated() {
        if !oementions.tableView.isHidden {
            topLine.frame = CGRect(
                x: oementions.tableView.frame.origin.x,
                y: oementions.tableView.frame.origin.y,
                width: oementions.tableView.frame.size.width,
                height: 1
            )
        }
    }
    
    func textViewShouldUpdateTextColor() {
        shouldUpdateTextColor = true
    }
}

class MentionCell: UITableViewCell {
    
    var contact: Contact? {
        didSet {
            avatar.image = AvatarMaker.shared().avatar(for: contact!, size: 16.0, masked: true)
            mentionNameLabel.text = contact?.displayName
            mentionIdentityLabel.text = contact?.identity
        }
    }
    
    var allContact = false {
        didSet {
            avatar.image = AvatarMaker.shared().unknownPersonImage()
            mentionNameLabel.text = "@" + BundleUtil.localizedString(forKey: "all")
            mentionIdentityLabel.text = nil
        }
    }
    
    private let mentionNameLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = UIFont.systemFont(ofSize: UIFont.systemFontSize)
        lbl.textAlignment = .left
        return lbl
    }()
    
    private let mentionIdentityLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = UIFont.systemFont(ofSize: UIFont.systemFontSize)
        lbl.textAlignment = .right
        lbl.numberOfLines = 0
        lbl.lineBreakMode = .byWordWrapping
        return lbl
    }()
    
    private let avatar: UIImageView = {
        let imgView = UIImageView()
        imgView.contentMode = .scaleAspectFit
        imgView.clipsToBounds = true
        return imgView
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        let stretchingView = UIView()
        stretchingView.setContentHuggingPriority(UILayoutPriority(rawValue: 1), for: .horizontal)
        stretchingView.backgroundColor = .clear
        stretchingView.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView(arrangedSubviews: [avatar, mentionNameLabel, stretchingView, mentionIdentityLabel])
        stackView.distribution = .fill
        stackView.axis = .horizontal
        stackView.spacing = 15
        stackView.alignment = .fill
        addSubview(stackView)
        avatar.anchor(
            top: nil,
            left: nil,
            bottom: nil,
            right: nil,
            paddingTop: 0,
            paddingLeft: 0,
            paddingBottom: 0,
            paddingRight: 0,
            width: 32.0,
            height: 32.0,
            enableInsets: false
        )

        stackView.anchor(
            top: topAnchor,
            left: leftAnchor,
            bottom: bottomAnchor,
            right: rightAnchor,
            paddingTop: 10,
            paddingLeft: 15,
            paddingBottom: 10,
            paddingRight: 15,
            width: 0,
            height: 0,
            enableInsets: false
        )
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension UIView {
    
    func anchor(
        top: NSLayoutYAxisAnchor?,
        left: NSLayoutXAxisAnchor?,
        bottom: NSLayoutYAxisAnchor?,
        right: NSLayoutXAxisAnchor?,
        paddingTop: CGFloat,
        paddingLeft: CGFloat,
        paddingBottom: CGFloat,
        paddingRight: CGFloat,
        width: CGFloat,
        height: CGFloat,
        enableInsets: Bool
    ) {
        let insets = safeAreaInsets
        let topInset = insets.top
        let bottomInset = insets.bottom
        
        translatesAutoresizingMaskIntoConstraints = false
        
        if let top = top {
            topAnchor.constraint(equalTo: top, constant: paddingTop + topInset).isActive = true
        }
        if let left = left {
            leftAnchor.constraint(equalTo: left, constant: paddingLeft).isActive = true
        }
        if let right = right {
            rightAnchor.constraint(equalTo: right, constant: -paddingRight).isActive = true
        }
        if let bottom = bottom {
            bottomAnchor.constraint(equalTo: bottom, constant: -paddingBottom - bottomInset).isActive = true
        }
        if height != 0 {
            heightAnchor.constraint(equalToConstant: height).isActive = true
        }
        if width != 0 {
            widthAnchor.constraint(equalToConstant: width).isActive = true
        }
    }
}
