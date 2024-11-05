//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
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

/// Display a text message
final class ChatViewTextMessageTableViewCell: ChatViewBaseTableViewCell, MeasurableCell {
    static var sizingCell = ChatViewTextMessageTableViewCell()
    
    /// Text message to display
    ///
    /// Reset it when the message had any changes to update data shown in the views (e.g. date or status symbol).
    var textMessageAndNeighbors: (message: TextMessageEntity, neighbors: ChatViewDataSource.MessageNeighbors)? {
        didSet {
            let block = {
                self.updateCell(for: self.textMessageAndNeighbors?.message)
                
                self.observe(
                    oldQuoteMessage: oldValue?.message.quoteMessage,
                    quoteMessage: self.textMessageAndNeighbors?.message.quoteMessage
                )
               
                super.setMessage(
                    to: self.textMessageAndNeighbors?.message,
                    with: self.textMessageAndNeighbors?.neighbors
                )
            }
               
            if let oldValue, oldValue.message.objectID == textMessageAndNeighbors?.message.objectID {
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
                    // view will animate in from the bottom.
                    UIView.animate(
                        withDuration: ChatViewConfiguration.ChatBubble.bubbleSizeChangeAnimationDurationInSeconds,
                        delay: ChatViewConfiguration.ChatBubble.bubbleSizeChangeAnimationDurationInSeconds,
                        options: .curveEaseInOut
                    ) {
                        block()
                    }
                }
                else {
                    UIView.performWithoutAnimation {
                        block()
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
                
            guard oldValue != shouldShowDateAndState else {
                return
            }
                
            // The length of the rendered text in the message might be shorter than `messageDateAndStateView`.
            // Thus we fully remove it to avoid having it set the width of the message bubble.
            if messageDateAndStateView.isHidden {
                contentStack.removeArrangedSubview(messageDateAndStateView)
            }
            else {
                contentStack.addArrangedSubview(messageDateAndStateView)
            }
        }
    }
    
    /// Used to observe changes of the quoted message, e.g. edits
    private var observers = [NSKeyValueObservation]()
    
    // MARK: - Views
    
    private lazy var messageQuoteStackView: MessageQuoteStackView = {
        let view = MessageQuoteStackView()
        
        let tapInteraction = UITapGestureRecognizer(target: self, action: #selector(quoteViewTapped))
        tapInteraction.delegate = self
        view.addGestureRecognizer(tapInteraction)
        
        return view
    }()
    
    private lazy var messageQuoteStackViewConstraints = [
        messageQuoteStackView.topAnchor.constraint(equalTo: containerView.topAnchor),
        messageQuoteStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
        messageQuoteStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
    ]
    
    private lazy var messageTextView = MessageTextView(messageTextViewDelegate: self)
    private lazy var messageDateAndStateView = MessageDateAndStateView()

    private lazy var contentStack = DefaultMessageContentStackView(arrangedSubviews: [
        messageTextView,
        messageDateAndStateView,
    ])
    
    private lazy var contentStackViewConstraints: [NSLayoutConstraint] = [
        contentStack.topAnchor.constraint(equalTo: containerView.topAnchor),
        contentStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
        contentStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        contentStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
    ]
    
    private lazy var contentStackViewWithQuoteConstraints: [NSLayoutConstraint] = [
        contentStack.topAnchor.constraint(
            equalTo: messageQuoteStackView.bottomAnchor,
            constant: ChatViewConfiguration.Quote.quoteTextCellDistance
        ),
        contentStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
        contentStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        contentStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
    ]
    
    private lazy var containerView: UIView = {
        let view = UIView()
        
        // This adds the margin to the chat bubble border
        view.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: -ChatViewConfiguration.Content.defaultTopBottomInset,
            leading: -ChatViewConfiguration.Content.defaultLeadingTrailingInset,
            bottom: -ChatViewConfiguration.Content.defaultTopBottomInset,
            trailing: -ChatViewConfiguration.Content.defaultLeadingTrailingInset
        )
        view.translatesAutoresizingMaskIntoConstraints = false
        
        return view
    }()

    // MARK: - Lifecycle
    
    deinit {
        invalidateObservers()
    }
    
    // MARK: - Configuration
    
    override func configureCell() {
        super.configureCell()
        
        containerView.addSubview(messageQuoteStackView)
        messageQuoteStackView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(contentStack)
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate(messageQuoteStackViewConstraints)
        NSLayoutConstraint.activate(contentStackViewWithQuoteConstraints)
   
        super.addContent(rootView: containerView)
    }
    
    // MARK: - Updates
    
    override func updateColors() {
        super.updateColors()
        
        messageQuoteStackView.updateColors()
        messageTextView.updateColors()
        messageDateAndStateView.updateColors()
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        containerView.isUserInteractionEnabled = !editing
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        if chatViewTableViewCellDelegate?.currentSearchText != nil {
            if selected {
                updateCell(for: textMessageAndNeighbors?.message)
            }
        }
    }
    
    private func updateCell(for textMessage: TextMessageEntity?) {
       
        // Quote stack view displaying / hiding
        if textMessage?.quoteMessage != nil {
            containerView.addSubview(messageQuoteStackView)
            NSLayoutConstraint.deactivate(contentStackViewConstraints)
            NSLayoutConstraint.activate(messageQuoteStackViewConstraints)
            NSLayoutConstraint.activate(contentStackViewWithQuoteConstraints)
        }
        else {
            messageQuoteStackView.removeFromSuperview()
            NSLayoutConstraint.deactivate(messageQuoteStackViewConstraints)
            NSLayoutConstraint.deactivate(contentStackViewWithQuoteConstraints)
            NSLayoutConstraint.activate(contentStackViewConstraints)
        }
        
        messageQuoteStackView.quoteMessage = textMessage?.quoteMessage
        messageTextView.text = textMessage?.text ?? ""
        messageDateAndStateView.message = textMessage

        updateAccessibility()
    }
    
    private func updateAccessibility() {
        guard textMessageAndNeighbors?.message.quoteMessage != nil else {
            return
        }
        accessibilityHint = #localize("quote_interaction_hint")
    }
    
    private func observe(oldQuoteMessage: QuoteMessage?, quoteMessage: QuoteMessage?) {
        
        guard let quoteMessage else {
            invalidateObservers()
            return
        }
        
        if oldQuoteMessage?.id != quoteMessage.id {
            invalidateObservers()
        }
        
        guard let quotedMessage = quoteMessage as? BaseMessage else {
            return
        }
        
        let editObserver = quotedMessage.observe(\.lastEditedAt) { [weak self] _, _ in
            self?.messageQuoteStackView.quoteMessage = quoteMessage
        }
        observers.append(editObserver)
        
        let deleteObserver = quotedMessage.observe(\.deletedAt) { [weak self] _, _ in
            self?.messageQuoteStackView.quoteMessage = quoteMessage
        }
        observers.append(deleteObserver)
    }
    
    private func invalidateObservers() {
        for observer in observers {
            observer.invalidate()
        }
        observers.removeAll()
    }

    // MARK: - Action Functions
    
    @objc func quoteViewTapped() {
        // swiftformat:disable:next acronyms
        guard let quotedMessageID = textMessageAndNeighbors?.message.quotedMessageId else {
            return
        }
        chatViewTableViewCellDelegate?.quoteTapped(on: quotedMessageID)
    }
}

// MARK: - MessageTextViewDelegate

extension ChatViewTextMessageTableViewCell: MessageTextViewDelegate {
    func showContact(identity: String) {
        chatViewTableViewCellDelegate?.show(identity: identity)
    }
    
    func didSelectText(in textView: MessageTextView?) {
        chatViewTableViewCellDelegate?.didSelectText(in: textView)
    }
}

// MARK: - Reusable

extension ChatViewTextMessageTableViewCell: Reusable { }

// MARK: - ChatViewMessageActions

extension ChatViewTextMessageTableViewCell: ChatViewMessageActions {
    
    func messageActionsSections() -> [ChatViewMessageActionsProvider.MessageActionsSection]? {

        guard let message = textMessageAndNeighbors?.message else {
            return nil
        }

        typealias Provider = ChatViewMessageActionsProvider
        
        // Ack
        let ackHandler = { (message: BaseMessage, ack: Bool) in
            self.chatViewTableViewCellDelegate?.sendAck(for: message, ack: ack)
        }
        
        // MessageMarkers
        let markStarHandler = { (message: BaseMessage) in
            self.chatViewTableViewCellDelegate?.toggleMessageMarkerStar(message: message)
        }
        
        // Quote
        let quoteHandler = {
            guard let chatViewTableViewCellDelegate = self.chatViewTableViewCellDelegate else {
                return
            }
            
            chatViewTableViewCellDelegate.showQuoteView(message: message)
        }
        
        // Edit Message
        let editHandler: Provider.DefaultHandler = {
            self.chatViewTableViewCellDelegate?.editMessage(for: message.objectID)
        }
        
        // Copy
        let copyHandler = {
            UIPasteboard.general.string = message.text
            NotificationPresenterWrapper.shared.present(type: .copySuccess)
        }
        
        // Details
        let detailsHandler: Provider.DefaultHandler = {
            self.chatViewTableViewCellDelegate?.showDetails(for: message.objectID)
        }
        
        // Select
        let selectHandler: Provider.DefaultHandler = {
            self.chatViewTableViewCellDelegate?.startMultiselect(with: message.objectID)
        }
        
        // Delete
        
        let willDelete: Provider.DefaultHandler = {
            self.chatViewTableViewCellDelegate?.willDeleteMessage(with: message.objectID)
        }
        
        let didDelete: Provider.DefaultHandler = {
            self.chatViewTableViewCellDelegate?.didDeleteMessages()
        }

        // Build menu
        return Provider.defaultActions(
            message: message,
            activityViewAnchor: contentView,
            popOverSource: chatBubbleView,
            ackHandler: ackHandler,
            markStarHandler: markStarHandler,
            quoteHandler: quoteHandler,
            editHandler: editHandler,
            copyHandler: copyHandler,
            shareItems: [message.text as Any],
            speakText: message.text,
            detailsHandler: detailsHandler,
            selectHandler: selectHandler,
            willDelete: willDelete,
            didDelete: didDelete
        )
    }
    
    override var accessibilityCustomActions: [UIAccessibilityCustomAction]? {
        get {
            var actions = messageTextView.accessibilityCustomActions(openURLHandler: { url in
                self.chatViewTableViewCellDelegate?.open(url: url)
            }, openDetailsHandler: { identity in
                self.showContact(identity: identity)
            }) ?? [UIAccessibilityCustomAction]()
            
            actions += buildAccessibilityCustomActions() ?? [UIAccessibilityCustomAction]()
            return actions
        }
        set {
            // No-op
        }
    }
}
