//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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
import ThreemaFramework
import UIKit

/// Cell to show a search results
final class GlobalSearchResultsTableViewCell: ThemedCodeStackTableViewCell {
    
    /// Message to show in this cell
    var message: BaseMessage? {
        didSet {
            updateCel(for: message)
        }
    }
    
    // MARK: - Private properties
       
    private lazy var markupParser = MarkupParser()

    // MARK: - Views
    
    private lazy var conversationNameLabel: UILabel = {
        let label = UILabel()

        label.font = UIFont.preferredFont(forTextStyle: ChatViewConfiguration.SearchResults.nameTextStyle)
        
        label.adjustsFontForContentSizeCategory = true
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                
        return label
    }()
    
    private lazy var dateLabel: UILabel = {
        let label = UILabel()
        
        label.font = UIFont.preferredFont(forTextStyle: ChatViewConfiguration.SearchResults.metadataTextStyle)
        
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
               
        return label
    }()
    
    private lazy var disclosureIndicatorImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "chevron.right"))
        
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            textStyle: ChatViewConfiguration.SearchResults.metadataTextStyle
        )
                
        return imageView
    }()
    
    private lazy var dateAndDisclosureIndicatorContainerView: UIView = {
        let view = UIView(frame: .zero)
        
        view.addSubview(dateLabel)
        view.addSubview(disclosureIndicatorImageView)
        
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        disclosureIndicatorImageView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: dateLabel.topAnchor),
            view.leadingAnchor.constraint(equalTo: dateLabel.leadingAnchor),
            view.bottomAnchor.constraint(equalTo: dateLabel.bottomAnchor),
            
            dateLabel.firstBaselineAnchor.constraint(equalTo: disclosureIndicatorImageView.firstBaselineAnchor),
            dateLabel.trailingAnchor.constraint(
                equalTo: disclosureIndicatorImageView.leadingAnchor,
                constant: -ChatViewConfiguration.SearchResults.metadataSpacing
            ),
            disclosureIndicatorImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        
        return view
    }()
    
    private lazy var topLineStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [
            conversationNameLabel,
            dateAndDisclosureIndicatorContainerView,
        ])
       
        stack.axis = .horizontal
        stack.spacing = ChatViewConfiguration.SearchResults.nameAndMetadataSpacing
        stack.alignment = .firstBaseline
        stack.distribution = .equalSpacing
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            stack.axis = .vertical
            stack.alignment = .leading
            
            disclosureIndicatorImageView.isHidden = true
            accessoryType = .disclosureIndicator
        }
               
        return stack
    }()
    
    private lazy var messagePreviewTextLabel: UILabel = {
        let label = UILabel()
        
        label.numberOfLines = 2
        
        label.font = UIFont.preferredFont(forTextStyle: ChatViewConfiguration.SearchResults.messagePreviewTextTextStyle)
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            label.numberOfLines = 3
        }
        
        return label
    }()
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        updateColors()
    }
    
    override func configureCell() {
        super.configureCell()
        
        contentStack.axis = .vertical
        contentStack.spacing = ChatViewConfiguration.SearchResults.verticalSpacing
        contentStack.alignment = .fill
        
        contentStack.addArrangedSubview(topLineStack)
        contentStack.addArrangedSubview(messagePreviewTextLabel)
    }
    
    // MARK: - Updates
    
    override func updateColors() {
        super.updateColors()
        
        Colors.setTextColor(Colors.text, label: conversationNameLabel)
        Colors.setTextColor(Colors.textLight, label: dateLabel)
        disclosureIndicatorImageView.tintColor = Colors.textLight
        
        Colors.setTextColor(Colors.textLight, label: messagePreviewTextLabel)
    }
    
    private func updateCel(for message: BaseMessage?) {
        guard let message else {
            conversationNameLabel.text = nil
            dateLabel.text = nil
            messagePreviewTextLabel.text = nil
            return
        }
        
        conversationNameLabel.text = message.conversation.displayName
        dateLabel.text = DateFormatter.relativeTimeTodayAndMediumDateOtherwise(for: message.sectionDate)
        
        if let previewableMessage = message as? PreviewableMessage {
            messagePreviewTextLabel.attributedText = previewableMessage
                .previewAttributedText(for: PreviewableMessageConfiguration.searchCell)
        }
    }
}

// MARK: - Reusable

extension GlobalSearchResultsTableViewCell: Reusable { }
