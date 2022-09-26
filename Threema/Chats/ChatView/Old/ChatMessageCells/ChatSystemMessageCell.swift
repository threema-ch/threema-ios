//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2022 Threema GmbH
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

@objc open class ChatSystemMessageCell: UITableViewCell {
    
    private var _systemMessage: SystemMessage?
    private var _msgText = UILabel()
    private var _msgBackground = UIImageView()
    private let _msgY: CGFloat = 12.0
    
    @objc override public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.backgroundColor = .clear
        
        var fontSize = roundf(UserSettings.shared().chatFontSize * 13 / 16.0)
        if fontSize < Float(kSystemMessageMinFontSize) {
            fontSize = Float(kSystemMessageMinFontSize)
        }
        else if fontSize > Float(kSystemMessageMaxFontSize) {
            fontSize = Float(kSystemMessageMaxFontSize)
        }
        
        _msgBackground.clearsContextBeforeDrawing = false
        _msgBackground.backgroundColor = Colors.backgroundSystemMessage
        _msgBackground.autoresizingMask = .flexibleWidth
        _msgBackground.layer.cornerRadius = 5
        contentView.addSubview(_msgBackground)
                
        _msgText.frame = CGRect(x: 20.0, y: _msgY, width: contentView.frame.size.width - 40.0, height: 20.0)
        _msgText.font = UIFont.systemFont(ofSize: CGFloat(roundf(fontSize)))
        _msgText.numberOfLines = 0
        _msgText.textAlignment = .center
        _msgText.autoresizingMask = .flexibleWidth
        _msgText.backgroundColor = .clear

        contentView.addSubview(_msgText)
    }
    
    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension ChatSystemMessageCell {
    // MARK: Override functions
    
    @objc open class func height(for message: BaseMessage!, forTableWidth tableWidth: CGFloat) -> CGFloat {
        let systemMessage = message as! SystemMessage
        let maxSize = CGSize(width: tableWidth - 40.0 - 32.0, height: CGFloat.greatestFiniteMagnitude)
        let text = systemMessage.format()

        var dummySystemLabel: UILabel?
        if dummySystemLabel == nil {
            dummySystemLabel = UILabel(frame: CGRect(x: 0.0, y: 0.0, width: maxSize.width, height: maxSize.height))
        }

        var fontSize = roundf(UserSettings.shared().chatFontSize * 13 / 16.0)
        if fontSize < Float(kSystemMessageMinFontSize) {
            fontSize = Float(kSystemMessageMinFontSize)
        }
        else if fontSize > Float(kSystemMessageMaxFontSize) {
            fontSize = Float(kSystemMessageMaxFontSize)
        }

        dummySystemLabel!.font = UIFont.systemFont(ofSize: CGFloat(roundf(fontSize)))
        dummySystemLabel!.numberOfLines = 0
        dummySystemLabel!.text = text
        
        let height = (dummySystemLabel?.sizeThatFits(maxSize).height)!
        
        return height
    }
    
    @objc override open func layoutSubviews() {
        let messageTextWidth = layoutMarginsGuide.layoutFrame.size.width - 32.0
        let textSize = _msgText.sizeThatFits(CGSize(width: messageTextWidth, height: CGFloat.greatestFiniteMagnitude))
        super.layoutSubviews()
        
        let bgSideMargin: CGFloat = 8.0
        let bgTopOffset: CGFloat = 6.0
        let bgHeightMargin: CGFloat = bgTopOffset * 2

        let backgroundWidth: CGFloat = bgSideMargin + textSize.width + bgSideMargin
        let backgroundX: CGFloat = (frame.size.width - backgroundWidth) / 2
        
        _msgBackground.frame = CGRect(
            x: backgroundX,
            y: _msgY - bgTopOffset,
            width: backgroundWidth,
            height: textSize.height + bgHeightMargin
        )
        _msgText.frame = CGRect(x: backgroundX + bgSideMargin, y: _msgY, width: textSize.width, height: textSize.height)
    }
    
    @objc func setMessage(systemMessage: SystemMessage) {
        guard case let .systemMessage(type: infoType) = systemMessage.systemMessageType else {
            return
        }

        _msgText.text = infoType.localizedMessage
        let att = NSAttributedString(
            string: infoType.localizedMessage,
            attributes: [NSAttributedString.Key.font: _msgText.font!]
        )
        _msgText.attributedText = _msgText.applyMarkup(for: att)

        updateColors()
    }
    
    @objc open func getContextMenu(_ indexPath: IndexPath!, point: CGPoint) -> UIContextMenuConfiguration! {
        nil
    }
}

extension ChatSystemMessageCell {
    // MARK: private functions
    
    private func updateColors() {
        _msgBackground.backgroundColor = Colors.backgroundSystemMessage
    }
}
