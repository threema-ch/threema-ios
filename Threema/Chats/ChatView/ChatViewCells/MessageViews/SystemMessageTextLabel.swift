//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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

import UIKit

/// Label with correct font and background for a system message
final class SystemMessageTextLabel: UILabel {
    
    override var text: String? {
        didSet {
            applyMarkup()
        }
    }
    
    // TODO: (IOS-3021) Remove this workaround
    override var textColor: UIColor! {
        didSet {
            if textColor != Colors.textLight {
                textColor = Colors.textLight
            }
        }
    }
    
    override var intrinsicContentSize: CGSize {
        var contentSize = super.intrinsicContentSize
        contentSize.height += ChatViewConfiguration.SystemMessage.Background.defaultSystemMessageTopBottomInset * 2
        contentSize.width += ChatViewConfiguration.SystemMessage.Background.defaultSystemMessageLeadingTrailingInset * 2
        return contentSize
    }

    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLabel()
        updateColors()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLabel()
        updateColors()
    }
    
    convenience init() {
        self.init(frame: .zero)
    }
    
    private func configureLabel() {
        font = ChatViewConfiguration.SystemMessageText.defaultFont
        adjustsFontForContentSizeCategory = true
        
        numberOfLines = 0
        lineBreakMode = .byWordWrapping
        textAlignment = .center
        
        layer.masksToBounds = true
        layer.cornerCurve = .continuous
        
        updateColors()
    }
    
    override func drawText(in rect: CGRect) {
        let insets = UIEdgeInsets(
            top: ChatViewConfiguration.SystemMessage.Background.defaultSystemMessageTopBottomInset,
            left: ChatViewConfiguration.SystemMessage.Background.defaultSystemMessageLeadingTrailingInset,
            bottom: ChatViewConfiguration.SystemMessage.Background.defaultSystemMessageTopBottomInset,
            right: ChatViewConfiguration.SystemMessage.Background.defaultSystemMessageLeadingTrailingInset
        )
        super.drawText(in: rect.inset(by: insets))
    }
    
    // MARK: - Update
    
    func updateColors() {
        textColor = Colors.textLight
        backgroundColor = Colors.newSystemMessageBackground
    }
    
    func updateCornerRadius() {
        
        // To make single line labels most of the time perfectly round, we apply a buffer to the check
        let buffer = 10.0
        
        // Ignore if view has no size
        if frame.height < 2 * ChatViewConfiguration.SystemMessage.Background.cornerRadius + buffer,
           frame.height != 0.0 {
            layer.cornerRadius = frame.height / 2
        }
        else {
            layer.cornerRadius = ChatViewConfiguration.SystemMessage.Background.cornerRadius
        }
    }
}
