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

import ThreemaFramework
import UIKit

/// Quote content stack
final class MessageQuoteStackView: UIStackView {
    
    /// Message to quote
    ///
    /// Reset it when the message had any changes to update the displayed quote
    var quoteMessage: QuoteMessage? {
        didSet {
            guard let quoteMessage = quoteMessage else {
                return
            }
            updateQuote(quoteMessage: quoteMessage)
        }
    }
    
    // MARK: - Properties
    
    private lazy var quoteBar: UIView = {
        let barView = UIView()
        barView.layer.cornerRadius = ChatViewConfiguration.Quote.quoteBarWidth / 2
        barView.widthAnchor.constraint(equalToConstant: ChatViewConfiguration.Quote.quoteBarWidth).isActive = true
        return barView
    }()
    
    private lazy var nameAndQuoteStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [nameLabel, quoteLabel])
        stackView.axis = .vertical
        return stackView
    }()
    
    private lazy var nameLabel: UILabel = {
        let nameLabel = UILabel()
        nameLabel.font = ChatViewConfiguration.Quote.nameFont
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.numberOfLines = 0
        return nameLabel
    }()
    
    private lazy var quoteLabel: UILabel = {
        let quoteLabel = UILabel()
        quoteLabel.font = ChatViewConfiguration.Quote.quoteFont
        quoteLabel.adjustsFontForContentSizeCategory = true
        quoteLabel.numberOfLines = 0
        return quoteLabel
    }()
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureStackView()
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        configureStackView()
    }
    
    convenience init() {
        self.init(frame: .zero)
    }
    
    private func configureStackView() {
        axis = .horizontal
        spacing = ChatViewConfiguration.Quote
            .quoteBarTextDistance
        
        // Add subviews
        addArrangedSubview(quoteBar)
        addArrangedSubview(nameAndQuoteStackView)
    }
    
    private func updateQuote(quoteMessage: QuoteMessage) {
        
        // Assign Values
        nameLabel.text = quoteMessage.quotedSender
        quoteLabel.attributedText = attributedText(for: quoteMessage)
    }
    
    func updateColors() {
        quoteBar.backgroundColor = Colors.primary
        
        Colors.setTextColor(Colors.textLight, label: nameLabel)
        // We need to assign the text of the quote label again to update the color of the icon properly
        quoteLabel.attributedText = attributedText(for: quoteMessage)
        Colors.setTextColor(Colors.textLight, label: quoteLabel)
    }
    
    /// Creates a trimmed attributed from a quoteMessage
    /// - Parameters:
    ///   - quoteMessage: Message to get text from
    /// - Returns: AttributedString with an optional icon
    private func attributedText(for quoteMessage: QuoteMessage?) -> NSAttributedString? {
        let quoteText: String
        let quoteIconName: String?
        
        // Assign values depending on type of quoted message
        switch quoteMessage?.quoteMessageType {
        case let .text(text):
            quoteText = text
            quoteIconName = nil
            
        case let .location(text, iconName), let .ballot(text, iconName), let .error(text, iconName):
            quoteText = text
            quoteIconName = iconName
            
            // TODO: Add other message types
            
        default:
            return nil
        }
        
        // Trim text as swift string to prevent emoji cropping
        let trimmedText = String(quoteText.prefix(ChatViewConfiguration.Quote.maxQuoteLength))
        let attributedText = NSMutableAttributedString(string: trimmedText)
    
        // If icon can't be found, we just return the text
        guard let iconName = quoteIconName,
              let image = UIImage(systemName: iconName) else {
            return attributedText
        }
            
        // Create string containing icon
        let icon = NSTextAttachment()
        icon.image = image.withConfiguration(ChatViewConfiguration.Quote.symbolConfiguration)
            .withTint(Colors.textLight)
        let iconString = NSAttributedString(attachment: icon)
            
        // Add icon and empty space to text
        let attributedSpace = NSAttributedString(string: " ")
        attributedText.insert(attributedSpace, at: 0)
        attributedText.insert(iconString, at: 0)
        
        return attributedText
    }
}
