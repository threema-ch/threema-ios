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

/// Display a ballot message
final class ChatViewBallotMessageTableViewCell: ChatViewBaseTableViewCell, MeasurableCell {
    
    static var sizingCell = ChatViewBallotMessageTableViewCell()
    
    /// Ballot message to display
    ///
    /// Reset it when the message had any changes to update data shown in the views (e.g. date or status symbol).
    var ballotMessage: BallotMessage? {
        didSet {
            super.setMessage(to: ballotMessage)
            updateCell(for: ballotMessage)

            observe(ballot: ballotMessage?.ballot, oldBallot: oldValue?.ballot)
        }
    }
    
    /// Used to observe changes of the ballot, e.g. new votes & state changes
    private var observers = [NSKeyValueObservation]()
    
    // MARK: - Views
    
    private lazy var ballotCellStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [messageQuoteStackView, iconMessageContentView])
        stackView.axis = .vertical
        return stackView
    }()
    
    /// Contains quote of original poll if poll is closed
    private lazy var messageQuoteStackView: MessageQuoteStackView = {
        let messageQuoteStackView = MessageQuoteStackView()
      
        messageQuoteStackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: ChatViewConfiguration.Content.defaultTopBottomInset,
            leading: ChatViewConfiguration.Content.defaultLeadingTrailingInset,
            bottom: 0, // Already set by iconMessageContentView
            trailing: ChatViewConfiguration.Content.defaultLeadingTrailingInset
        )
        messageQuoteStackView.isLayoutMarginsRelativeArrangement = true

        return messageQuoteStackView
    }()
    
    /// Contains icon and message of poll
    private lazy var iconMessageContentView = IconMessageContentView(iconView: iconView, arrangedSubviews: [
        messageTextView,
        messageSecondaryTextLabel,
        messageDateAndStateView,
    ])
    
    private lazy var defaultSymbol = UIImage(systemName: "chart.pie.fill")?.withRenderingMode(.alwaysOriginal)

    private lazy var iconView: UIImageView = {
        let imageView = UIImageView(image: defaultSymbol)
        let configuration = ChatViewConfiguration.Text.symbolConfiguration
        imageView.preferredSymbolConfiguration = configuration
        imageView.contentMode = .center
        imageView.accessibilityElementsHidden = true
        return imageView
    }()
    
    private lazy var messageTextView = MessageTextView(messageTextViewDelegate: self)
    private lazy var messageSecondaryTextLabel = MessageSecondaryTextLabel()
    private lazy var messageDateAndStateView = MessageDateAndStateView()
    
    // MARK: - Lifecycle
    
    deinit {
        invalidateObservers()
    }
    
    // MARK: - Configuration
    
    override func configureCell() {
        super.configureCell()
        
        super.addContent(rootView: ballotCellStackView)
    }
    
    // MARK: - Updates
    
    override func updateColors() {
        super.updateColors()
        
        // We must change the icon based on the closing state and re-assign the attributed text for the icons to change color as well
        if let ballotMessage = ballotMessage {
            if ballotMessage.isClosed() {
                iconView.image = iconView.image?.withTintColor(Colors.textLight)
            }
            else {
                iconView.image = iconView.image?.withTintColor(Colors.text)
                messageSecondaryTextLabel.attributedText =
                    ballotMessage.ballot.localizedMessageSecondaryText(
                        configuration: ChatViewConfiguration.SecondaryText.symbolConfiguration
                    )
            }
        }
        
        defaultSymbol = defaultSymbol?.withTint(Colors.text)
        
        // Other views
        messageQuoteStackView.updateColors()
        messageTextView.updateColors()
        messageSecondaryTextLabel.updateColors()
        messageDateAndStateView.updateColors()
    }
    
    private func updateCell(for ballotMessage: BallotMessage?) {
        // By accepting an optional the data is automatically reset when the ballot message is set to `nil`
                
        messageQuoteStackView.quoteMessage = ballotMessage?.quoteMessage
        
        // Distinguish between closed and open poll message
        if ballotMessage?.isClosed() ?? false {
            messageQuoteStackView.isHidden = false
            messageTextView.text = nil
            messageTextView.isHidden = true
            
            if let symbol = ballotMessage?.ballot.stateSymbol {
                iconView.image = symbol.withConfiguration(ChatViewConfiguration.Text.symbolConfiguration)
            }
            
            messageSecondaryTextLabel.text = ballotMessage?.ballot.localizedClosingMessageText
        }
        else {
            messageQuoteStackView.isHidden = true
            messageTextView.isHidden = false
            messageTextView.text = ballotMessage?.ballot.title
            
            // We need to assign it with the color here again, otherwise there is an issue during re-use
            iconView.image = defaultSymbol
            messageSecondaryTextLabel.attributedText =
                ballotMessage?.ballot.localizedMessageSecondaryText(
                    configuration: ChatViewConfiguration.SecondaryText.smallSymbolConfiguration
                )
        }
        messageDateAndStateView.message = ballotMessage
    }
    
    private func observe(ballot: Ballot?, oldBallot: Ballot?) {
        
        // Also handles case when `ballot` nil
        if oldBallot != ballot {
            invalidateObservers()
        }
        
        guard let ballot = ballot else {
            return
        }
        
        let dateObserver = ballot.observe(\.modifyDate) { [weak self] _, _ in
            self?.updateCell(for: self?.ballotMessage)
        }
        let stateObserver = ballot.observe(\.state) { [weak self] _, _ in
            self?.updateCell(for: self?.ballotMessage)
        }
        
        observers.append(dateObserver)
        observers.append(stateObserver)
    }
    
    private func invalidateObservers() {
        observers.forEach { observer in
            observer.invalidate()
        }
        observers.removeAll()
    }
}

// MARK: - MessageTextViewDelegate

extension ChatViewBallotMessageTableViewCell: MessageTextViewDelegate { }

// MARK: - Reusable

extension ChatViewBallotMessageTableViewCell: Reusable { }