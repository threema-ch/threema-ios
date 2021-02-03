//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2021 Threema GmbH
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

@objc open class ChatSystemMessageCell: UITableViewCell {
    
    private var _systemMessage: SystemMessage?
    private var _msgText = UILabel.init()
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
        _msgBackground.backgroundColor = Colors.chatSystemMessageBackground()
        _msgBackground.autoresizingMask = .flexibleWidth
        _msgBackground.layer.cornerRadius = 5
        contentView.addSubview(_msgBackground)
                
        _msgText.frame = CGRect.init(x: 20.0, y: _msgY, width: contentView.frame.size.width - 40.0, height: 20.0)
        _msgText.font = UIFont.boldSystemFont(ofSize: CGFloat(roundf(fontSize)))
        _msgText.textColor = Colors.fontNormal()
        _msgText.numberOfLines = 0
        _msgText.textAlignment = .left
        _msgText.autoresizingMask = .flexibleWidth
        _msgText.backgroundColor = .clear

        contentView.addSubview(_msgText)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension ChatSystemMessageCell {
    // MARK: Override functions
    
    @objc open class func height(for message: BaseMessage!, forTableWidth tableWidth: CGFloat) -> CGFloat {
        let systemMessage = message as! SystemMessage
        let maxSize = CGSize.init(width: tableWidth - 40.0 - 32.0, height: CGFloat.greatestFiniteMagnitude)
        let text = systemMessage.format()

        var dummySystemLabel: UILabel? = nil
        if dummySystemLabel == nil {
            dummySystemLabel = UILabel.init(frame: CGRect.init(x: 0.0, y: 0.0, width: maxSize.width, height: maxSize.height))
        }

        var fontSize = roundf(UserSettings.shared().chatFontSize * 13 / 16.0)
        if fontSize < Float(kSystemMessageMinFontSize) {
            fontSize = Float(kSystemMessageMinFontSize)
        }
        else if fontSize > Float(kSystemMessageMaxFontSize) {
            fontSize = Float(kSystemMessageMaxFontSize)
        }

        dummySystemLabel!.font = UIFont.boldSystemFont(ofSize: CGFloat(roundf(fontSize)))
        dummySystemLabel!.numberOfLines = 3
        dummySystemLabel!.text = text
        
        let height = (dummySystemLabel?.sizeThatFits(maxSize).height)!
        
        return height
    }
    
    @objc override open func layoutSubviews() {
        let messageTextWidth = self.layoutMarginsGuide.layoutFrame.size.width - 32.0
        let textSize = _msgText.sizeThatFits(CGSize.init(width: messageTextWidth, height: CGFloat.greatestFiniteMagnitude))
        super.layoutSubviews()
        
        let bgSideMargin: CGFloat = 8.0
        let bgTopOffset: CGFloat = 6.0
        let bgHeightMargin: CGFloat = bgTopOffset * 2

        let backgroundWidth: CGFloat = bgSideMargin + textSize.width + bgSideMargin
        let backgroundX: CGFloat = (self.frame.size.width - backgroundWidth) / 2
        
        _msgBackground.frame = CGRect(x: backgroundX, y: _msgY - bgTopOffset, width: backgroundWidth, height: textSize.height + bgHeightMargin)
        _msgText.frame = CGRect.init(x: backgroundX + bgSideMargin, y: _msgY, width: textSize.width, height: textSize.height)
    }
    
    @objc func setMessage(systemMessage: SystemMessage) {
        _msgText.text = systemMessage.format()
        setupColors()
    }
    
    @objc @available(iOS 13.0, *)
    open func getContextMenu(_ indexPath: IndexPath!, point: CGPoint) -> UIContextMenuConfiguration! {
        return nil
    }
}

extension ChatSystemMessageCell {
    // MARK: private functions
    
    private func setupColors() {
        _msgText.textColor = Colors.fontNormal()
        _msgBackground.backgroundColor = Colors.chatSystemMessageBackground()
    }
}
