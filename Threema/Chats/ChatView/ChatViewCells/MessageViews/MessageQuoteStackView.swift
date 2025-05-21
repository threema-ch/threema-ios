//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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
import ThreemaMacros
import UIKit

/// Quote content stack
final class MessageQuoteStackView: UIStackView {
    
    enum ThumbnailDistribution {
        case fill
        case spaced
    }
    
    /// Message to quote
    ///
    /// Reset it when the message had any changes to update the displayed quote
    var quoteMessage: QuoteMessage? {
        didSet {
            guard let quoteMessage else {
                updateMissingQuote()
                return
            }
            
            updateQuote(quoteMessage: quoteMessage)
        }
    }
    
    /// If set to `.spaced` the `MessageQuoteStackView` will use the maximum allowed width for space between name / text
    /// and thumbnail for this cell
    /// Don't use this if there is no thumbnail.
    /// Defaults to no spacing.
    var thumbnailDistribution: ThumbnailDistribution = .fill {
        didSet {
            switch thumbnailDistribution {
            case .fill:
                removeArrangedSubview(spacerView)
            case .spaced:
                if !arrangedSubviews.contains(where: { $0 == spacerView }) {
                    insertArrangedSubview(spacerView, at: 2)
                }
            }
        }
    }
    
    // MARK: - Private properties
    
    private lazy var quoteBar: UIView = {
        let barView = UIView()
        
        barView.layer.cornerRadius = ChatViewConfiguration.Quote.quoteBarWidth / 2
        
        barView.widthAnchor.constraint(equalToConstant: ChatViewConfiguration.Quote.quoteBarWidth).isActive = true
        
        return barView
    }()
    
    private lazy var nameLabel: RTLAligningLabel = {
        let nameLabel = RTLAligningLabel()
        nameLabel.font = ChatViewConfiguration.Quote.nameFont
        nameLabel.textColor = .secondaryLabel
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.numberOfLines = 0
      
        return nameLabel
    }()
    
    private lazy var quoteLabel: RTLAligningLabel = {
        let quoteLabel = RTLAligningLabel()
        quoteLabel.adjustsFontForContentSizeCategory = true
        quoteLabel.numberOfLines = ChatViewConfiguration.Quote.maxQuoteLines
        quoteLabel.textColor = .secondaryLabel
        
        return quoteLabel
    }()
    
    private lazy var nameAndQuoteStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [nameLabel, quoteLabel])
        
        stackView.axis = .vertical

        return stackView
    }()
    
    private lazy var spacerView: UIView = {
        let spacerView = UIView()
        
        let spacerViewWidthConstraint = spacerView.widthAnchor.constraint(equalToConstant: .greatestFiniteMagnitude)
        spacerViewWidthConstraint.priority = .defaultLow
        spacerViewWidthConstraint.isActive = true
        
        return spacerView
    }()
    
    private lazy var quoteThumbnailView: UIImageView = {
        let thumbnailView = UIImageView(image: nil)

        thumbnailView.contentMode = .scaleAspectFill
        thumbnailView.clipsToBounds = true

        thumbnailView.layer.cornerRadius = ChatViewConfiguration.Quote.thumbnailCornerRadius
        thumbnailView.layer.cornerCurve = .continuous

        thumbnailView.heightAnchor.constraint(lessThanOrEqualToConstant: scaledSize).isActive = true
        thumbnailView.widthAnchor.constraint(equalTo: thumbnailView.heightAnchor).isActive = true
        thumbnailView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        thumbnailView.accessibilityIgnoresInvertColors = true
        
        return thumbnailView
    }()
    
    private lazy var playButtonView = BlurCircleView(sfSymbolName: "play.fill", configuration: .thumbnail)
    
    private lazy var playButtonViewConstraints = [
        playButtonView.centerXAnchor.constraint(equalTo: quoteThumbnailView.centerXAnchor),
        playButtonView.centerYAnchor.constraint(equalTo: quoteThumbnailView.centerYAnchor),
    ]
    
    private var scaledSize: CGFloat {
        let defaultSize: CGFloat = ChatViewConfiguration.Quote.thumbnailDefaultSize
        return UIFontMetrics(forTextStyle: .footnote).scaledValue(for: defaultSize)
    }
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureStackView()
        configureLayout()
        
        updateContent()
        updateLayout()
    }
    
    convenience init() {
        self.init(frame: .zero)
    }
    
    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("Not implemented")
    }

    // MARK: - Configuration
    
    private func configureStackView() {
        axis = .horizontal
        spacing = ChatViewConfiguration.Quote.quoteBarTextDistance
        alignment = .top
        
        isLayoutMarginsRelativeArrangement = true

        // Add subviews
        addArrangedSubview(quoteBar)
        addArrangedSubview(nameAndQuoteStackView)
        addArrangedSubview(quoteThumbnailView)
    }
    
    private func configureLayout() {
        // Quote Bar
        NSLayoutConstraint.activate([
            quoteBar.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            quoteBar.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor),
        ])
    }
    
    // MARK: - Updates

    private func updateQuote(quoteMessage: QuoteMessage) {
        // Assign Values & configure layout
        nameLabel.text = quoteMessage.localizedSenderName
        updateQuoteBarColor()

        updateContent()
        updateLayout()
    }
    
    private func updateMissingQuote() {
        // Assign Values & configure layout
        nameLabel.text = nil
        updateQuoteBarColor()

        nameAndQuoteStackView.spacing = 0
        quoteLabel.text = #localize("quote_not_found")
        quoteLabel.font = PreviewableMessageConfiguration.quote.font.italic()
        
        updateLayout()
    }
    
    func updateColors() {
        updateQuoteBarColor()
        
        // The image in the quote only gets updated if we set it new again
        updateContent()
    }
    
    private func updateQuoteBarColor() {
        quoteBar.backgroundColor = quoteMessage?.senderIDColor ?? .tintColor
    }
    
    private func updateContent() {
        
        guard let quoteMessage else {
            return
        }
        
        if nameLabel.text != nil {
            nameAndQuoteStackView.spacing = ChatViewConfiguration.Quote.quoteNameTextDistance
        }
        else {
            nameAndQuoteStackView.spacing = 0
        }
        
        quoteLabel.attributedText = quoteMessage.previewAttributedText(for: .quote)
        
        // We need to set the font explicitly to make the label set its height correctly
        if quoteMessage.deletedAt == nil {
            quoteLabel.font = PreviewableMessageConfiguration.quote.font
        }
        else {
            quoteLabel.font = PreviewableMessageConfiguration.quote.font.italic()
        }
        
        if let (thumbnail, _) = quoteMessage.mediaPreview, quoteMessage.deletedAt == nil {
            quoteThumbnailView.image = thumbnail
        }
    }
    
    private func updateLayout() {
        
        // Don't show thumbnail with accessibility fonts
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            playButtonView.removeFromSuperview()
            quoteThumbnailView.image = nil
            quoteThumbnailView.isHidden = true
            return
        }
        
        if let (_, isPlayable) = quoteMessage?.mediaPreview {
            
            quoteThumbnailView.isHidden = false

            if isPlayable {
                playButtonView.translatesAutoresizingMaskIntoConstraints = false
                quoteThumbnailView.addSubview(playButtonView)
                NSLayoutConstraint.activate(playButtonViewConstraints)
            }
            else {
                playButtonView.removeFromSuperview()
            }
        }
        else {
            // Reset everything concerning the thumbnail
            playButtonView.removeFromSuperview()
            quoteThumbnailView.image = nil
            quoteThumbnailView.isHidden = true
        }
    }
}
