//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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
    var ballotMessageAndNeighbors: (message: BallotMessage, neighbors: ChatViewDataSource.MessageNeighbors)? {
        didSet {
            let block = {
                self.updateCell(for: self.ballotMessageAndNeighbors?.message)
                self.observe(
                    ballot: self.ballotMessageAndNeighbors?.message.ballot,
                    oldBallot: oldValue?.message.ballot
                )
                
                super.setMessage(
                    to: self.ballotMessageAndNeighbors?.message,
                    with: self.ballotMessageAndNeighbors?.neighbors
                )
            }
            
            if let oldValue, oldValue.message.objectID == ballotMessageAndNeighbors?.message.objectID {
                UIView.animate(
                    withDuration: ChatViewConfiguration.ChatBubble.bubbleSizeChangeAnimationDurationInSeconds,
                    delay: 0.0,
                    options: .curveEaseInOut
                ) {
                    block()
                    self.layoutIfNeeded()
                }
            }
            else {
                block()
            }
        }
    }
    
    override var shouldShowDateAndState: Bool {
        didSet {
            // Both of these animations are typically covered within a bigger animation block
            // or a block that doesn't animate at all. Both cases look good.
            if shouldShowDateAndState {
                
                let block = {
                    self.messageDateAndStateView.alpha = 1.0
                    self.messageDateAndStateView.isHidden = false
                }
                
                if !oldValue {
                    // When adding the date and state view, this is an animation that doesn't look half bad since the
                    // view will
                    // animate in from the bottom.
                    UIView.animate(
                        withDuration: ChatViewConfiguration.ChatBubble.bubbleSizeChangeAnimationDurationInSeconds,
                        delay: ChatViewConfiguration.ChatBubble.bubbleSizeChangeAnimationDurationInSeconds,
                        options: .curveEaseInOut
                    ) {
                        block()
                    } completion: { _ in
                        // This is used to work around a bug where the ack symbols didn't have the correct baseline.
                        UIView.performWithoutAnimation {
                            self.messageDateAndStateView.setNeedsLayout()
                            self.messageDateAndStateView.layoutIfNeeded()
                        }
                    }
                }
                else {
                    UIView.performWithoutAnimation {
                        block()
                        
                        // This is used to work around a bug where the ack symbols didn't have the correct baseline.
                        // It is very unclear why this is needed in addition to
                        self.messageDateAndStateView.setNeedsLayout()
                        self.messageDateAndStateView.layoutIfNeeded()
                    }
                }
            }
            else {
                // We don't use the same animation when hiding the date and state view because it'll animate out to the
                // top
                // and will cover the text which is still showing in the cell.
                UIView.performWithoutAnimation {
                    self.messageDateAndStateView.alpha = 0.0
                }
            }
            
            messageDateAndStateView.isHidden = !shouldShowDateAndState
        }
    }
    
    /// Used to observe changes of the ballot, e.g. new votes & state changes
    private var observers = [NSKeyValueObservation]()
    
    // MARK: - Views
    
    private lazy var ballotCellStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [messageQuoteStackView, iconMessageContentView])
        stackView.axis = .vertical
        
        // This adds the margin to the chat bubble border
        stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: -ChatViewConfiguration.Content.defaultTopBottomInset,
            leading: -ChatViewConfiguration.Content.defaultLeadingTrailingInset,
            bottom: -ChatViewConfiguration.Content.defaultTopBottomInset,
            trailing: -ChatViewConfiguration.Content.defaultLeadingTrailingInset
        )
        
        return stackView
    }()
    
    /// Contains quote of original poll if poll is closed
    private lazy var messageQuoteStackView: MessageQuoteStackView = {
        let messageQuoteStackView = MessageQuoteStackView()
      
        messageQuoteStackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 0,
            leading: 0,
            bottom: ChatViewConfiguration.Content.defaultTopBottomInset,
            trailing: 0
        )
        messageQuoteStackView.isLayoutMarginsRelativeArrangement = true

        return messageQuoteStackView
    }()
    
    /// Contains icon and message of poll
    private lazy var iconMessageContentView = IconMessageContentView(iconView: iconView, arrangedSubviews: [
        messageTextView,
        messageSecondaryTextLabel,
        messageDateAndStateView,
    ]) { [weak self] in
        guard let strongSelf = self else {
            return
        }
        
        strongSelf.chatViewTableViewCellDelegate?.didTap(
            message: strongSelf.ballotMessageAndNeighbors?.message,
            in: strongSelf
        )
    }
    
    private lazy var defaultSymbol = UIImage(systemName: "chart.pie.fill")?.withRenderingMode(.alwaysOriginal)

    private lazy var iconView: UIImageView = {
        let imageView = UIImageView(image: defaultSymbol)
        let configuration = ChatViewConfiguration.Text.symbolConfiguration
        imageView.preferredSymbolConfiguration = configuration
        imageView.contentMode = .center
        imageView.accessibilityElementsHidden = true
        return imageView
    }()
    
    private lazy var messageTextView = MessageTextView(messageTextViewDelegate: nil)
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
        
        // We must change the icon based on the closing state and re-assign the attributed text for the icons to change
        // color as well
        if let ballotMessage = ballotMessageAndNeighbors?.message, !ballotMessage.willBeDeleted {
            if ballotMessage.isClosed() {
                iconView.image = iconView.image?.withTintColor(Colors.textLight)
            }
            else {
                iconView.image = iconView.image?.withTintColor(Colors.text)
                messageSecondaryTextLabel.attributedText =
                    ballotMessage.ballot?.localizedMessageSecondaryText(
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
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)

        ballotCellStackView.isUserInteractionEnabled = !editing
    }
    
    private func updateCell(for ballotMessage: BallotMessage?) {
        // By accepting an optional the data is automatically reset when the ballot message is set to `nil`
        
        guard !(ballotMessage?.willBeDeleted ?? false) else {
            return
        }
                
        messageQuoteStackView.quoteMessage = ballotMessage?.quoteMessage
        
        // Distinguish between closed and open poll message
        if ballotMessage?.isClosed() ?? false {
            messageQuoteStackView.isHidden = false
            messageTextView.text = ""
            messageTextView.isHidden = true
            
            if let symbol = ballotMessage?.ballot.stateSymbol {
                iconView.image = symbol.withConfiguration(ChatViewConfiguration.Text.symbolConfiguration)
            }
            
            messageSecondaryTextLabel.text = ballotMessage?.ballot?.localizedClosingMessageText
        }
        else {
            messageQuoteStackView.isHidden = true
            messageTextView.isHidden = false
            messageTextView.text = ballotMessage?.ballot?.title ?? ""
            
            // We need to assign it with the color here again, otherwise there is an issue during re-use
            iconView.image = defaultSymbol
            messageSecondaryTextLabel.attributedText =
                ballotMessage?.ballot?.localizedMessageSecondaryText(
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
        
        guard let ballot else {
            return
        }
        
        let dateObserver = ballot.observe(\.modifyDate) { [weak self] _, _ in
            self?.updateCell(for: self?.ballotMessageAndNeighbors?.message)
        }
        let stateObserver = ballot.observe(\.state) { [weak self] _, _ in
            self?.updateCell(for: self?.ballotMessageAndNeighbors?.message)
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

// MARK: - Reusable

extension ChatViewBallotMessageTableViewCell: Reusable { }

// MARK: - ChatViewMessageAction

extension ChatViewBallotMessageTableViewCell: ChatViewMessageAction {
    
    func messageActions() -> [ChatViewMessageActionProvider.MessageAction]? {

        guard let message = ballotMessageAndNeighbors?.message else {
            return nil
        }
        
        typealias Provider = ChatViewMessageActionProvider
        
        // Details
        let detailsHandler = {
            self.chatViewTableViewCellDelegate?.showDetails(for: message.objectID)
        }
        
        let detailsAction = Provider.detailsAction(handler: detailsHandler)
        
        let editAction = Provider.editAction {
            self.chatViewTableViewCellDelegate?.startMultiselect(with: message.objectID)
        }
        
        // Delete
        let willDelete = {
            self.chatViewTableViewCellDelegate?.willDeleteMessage(with: message.objectID)
        }
        
        let didDelete = {
            self.chatViewTableViewCellDelegate?.didDeleteMessages()
        }
        
        let deleteAction = Provider.deleteAction(message: message, willDelete: willDelete, didDelete: didDelete)
        
        return [detailsAction, editAction, deleteAction]
    }
    
    override var accessibilityCustomActions: [UIAccessibilityCustomAction]? {
        get {
            buildAccessibilityCustomActions()
        }
        set {
            // No-op
        }
    }
}
