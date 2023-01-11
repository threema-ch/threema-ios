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

/// Label with correct font and background for a work private info message
final class SystemMessageWorkConsumerLabel: UILabel {
    
    typealias textConfig = ChatViewConfiguration.SystemMessageText
    typealias backgroundConfig = ChatViewConfiguration.SystemMessage.Background

    var type: SystemMessage.WorkConsumerInfoType? {
        didSet {
            setLabelContent()
            updateColors()
        }
    }
    
    override var intrinsicContentSize: CGSize {
        var contentSize = super.intrinsicContentSize
        contentSize.height += backgroundConfig.defaultSystemMessageTopBottomInset * 2
        contentSize.width += backgroundConfig
            .defaultSystemMessageLeadingTrailingInset + (backgroundConfig.cornerRadius / 2)
        return contentSize
    }

    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // Observe to adapt icon to new font size
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(setLabelContent),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
        
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
        font = textConfig.workConsumerFont
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
            top: backgroundConfig.defaultSystemMessageTopBottomInset,
            left: backgroundConfig.cornerRadius / 2,
            bottom: backgroundConfig.defaultSystemMessageTopBottomInset,
            right: backgroundConfig.defaultSystemMessageLeadingTrailingInset
        )
        super.drawText(in: rect.inset(by: insets))
    }
    
    // MARK: - Update
    
    @objc func setLabelContent() {
        guard let type = type else {
            return
        }

        let attributedLabelText = NSMutableAttributedString(string: type.localizedMessage)
        
        // If no symbol is found we just assign the text
        guard let symbol = type.symbol else {
            attributedText = attributedLabelText
            return
        }
        
        let scaledFontSize = UIFontMetrics.default.scaledValue(for: textConfig.workConsumerFont.capHeight)
        let image = createIcon(symbol: symbol, size: scaledFontSize)

        let icon = NSTextAttachment()
        icon.image = image
        icon.bounds = CGRect(
            x: 0,
            y: (scaledFontSize - image.size.height) / 2,
            width: image.size.width,
            height: image.size.height
        )
        
        let iconString = NSAttributedString(attachment: icon)
        
        // Add icon and safe empty space to text
        let attributedSpace = NSAttributedString(string: " ")
        attributedLabelText.insert(attributedSpace, at: 0)
        attributedLabelText.insert(iconString, at: 0)
        
        attributedText = attributedLabelText
    }
    
    func updateColors() {
        Colors.setTextColor(Colors.white, label: self)
        
        switch type {
        case .work, .none:
            backgroundColor = Colors.threemaWorkColor
        case .consumer:
            backgroundColor = Colors.threemaConsumerColor
        }
    }
    
    func updateCornerRadius() {
        
        // To make single line labels most of the time perfectly round, we apply a buffer to the check
        let buffer = 10.0
        
        // Ignore if view has no size
        if frame.height < 2 * backgroundConfig.cornerRadius + buffer, frame.height != 0.0 {
            layer.cornerRadius = frame.height / 2
        }
        else {
            layer.cornerRadius = backgroundConfig.cornerRadius
        }
    }
    
    private func createIcon(symbol: UIImage, size: CGFloat) -> UIImage {
        let icon = symbol
            .withConfiguration(textConfig.workConsumerSymbolConfiguration)
        
        let height = size * 1.75
        let resizedIcon = icon.resizedImage(newSize: CGSize(width: height, height: height))
        return resizedIcon
    }
}
