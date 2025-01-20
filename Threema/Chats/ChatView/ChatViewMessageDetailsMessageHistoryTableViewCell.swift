//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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
import ThreemaFramework
import ThreemaMacros

final class ChatViewMessageDetailsMessageHistoryTableViewCell: ThemedCodeTableViewCell {
    
    var historyItem: EditHistoryItem? {
        didSet {
            guard let historyItem else {
                return
            }
            updateView(with: historyItem)
        }
    }
    
    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        
        label.numberOfLines = 0
        
        label.translatesAutoresizingMaskIntoConstraints = false
        
        return label
    }()
    
    private lazy var dateLabel: UILabel = {
        let label = UILabel()
        
        label.font = UIFont.preferredFont(forTextStyle: ChatViewConfiguration.MessageMetadata.textStyle)
        
        label.translatesAutoresizingMaskIntoConstraints = false

        return label
    }()
    
    private lazy var markupParser = MarkupParser()
    
    override func configureCell() {
        super.configureCell()
                
        selectionStyle = .none
        
        contentView.addSubview(messageLabel)
        contentView.addSubview(dateLabel)
        
        NSLayoutConstraint.activate([
            messageLabel.widthAnchor.constraint(
                equalTo: contentView.readableContentGuide.widthAnchor
            ),
            messageLabel.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            
            messageLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
           
            dateLabel.topAnchor.constraint(
                equalTo: messageLabel.bottomAnchor,
                constant: ChatViewConfiguration.Content.contentAndMetadataSpace
            ),
            dateLabel.bottomAnchor.constraint(
                equalTo: contentView.layoutMarginsGuide.bottomAnchor
            ),
            dateLabel.trailingAnchor.constraint(
                equalTo: contentView.layoutMarginsGuide.trailingAnchor
            ),
        ])
    }
    
    private func updateView(with historyItem: EditHistoryItem) {
        // Text
        if historyItem.text != "" {
            let markedUpString = NSMutableAttributedString(
                attributedString: markupParser.previewString(
                    for: historyItem.text,
                    font: .preferredFont(forTextStyle: .body)
                )
            )
            markedUpString.removeAttribute(
                NSAttributedString.Key.link,
                range: NSRange(location: 0, length: markedUpString.length)
            )
            markedUpString.removeAttribute(
                NSAttributedString.Key.foregroundColor,
                range: NSRange(location: 0, length: markedUpString.length)
            )
            
            messageLabel.attributedText = markedUpString
        }
        else {
            messageLabel.text = #localize("detailView_edit_history_no_caption")
            messageLabel.font = UIFont.preferredFont(forTextStyle: .body).italic()
        }
        
        // Date
        let dateLabelText: String =
            if !Calendar.current.isDate(historyItem.date, inSameDayAs: .now) {
                DateFormatter.relativeMediumDateAndShortTime(for: historyItem.date)
            }
            else {
                DateFormatter.shortStyleTimeNoDate(historyItem.date)
            }
        
        if historyItem.isCurrent {
            dateLabel.text = "\(#localize("detailView_edit_history_current")) • \(dateLabelText)"
        }
        else {
            dateLabel.text = dateLabelText
        }
        
        messageLabel.textColor = historyItem.text != "" ? .label : .secondaryLabel
        dateLabel.textColor = .secondaryLabel
    }
}

// MARK: - Reusable

extension ChatViewMessageDetailsMessageHistoryTableViewCell: Reusable { }
