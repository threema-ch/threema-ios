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

import Foundation
import ThreemaFramework

final class ChatViewDeletedMessageTableViewCell: ChatViewBaseTableViewCell, MeasurableCell {
    static var sizingCell = ChatViewDeletedMessageTableViewCell()

    private lazy var deletedMessageView = DeletedMessageView()
    private lazy var messageDateAndStateView = MessageDateAndStateView()

    /// Deleted message to display
    ///
    /// Reset it when the message had any changes to update data shown in the views (e.g. date or status symbol).
    var deletedMessageAndNeighbors: (message: BaseMessage, neighbors: ChatViewDataSource.MessageNeighbors)? {
        didSet {
            let block = {
                NSLayoutConstraint.activate(self.contentStackViewConstraints)
                self.messageDateAndStateView.message = self.deletedMessageAndNeighbors?.message

                super.setMessage(
                    to: self.deletedMessageAndNeighbors?.message,
                    with: self.deletedMessageAndNeighbors?.neighbors
                )
            }

            if let oldValue, oldValue.message.objectID == deletedMessageAndNeighbors?.message.objectID {
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

    private lazy var contentStack = DefaultMessageContentStackView(arrangedSubviews: [
        deletedMessageView,
        messageDateAndStateView,
    ])

    private lazy var contentStackViewConstraints: [NSLayoutConstraint] = {
        [
            contentStack.topAnchor.constraint(equalTo: containerView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            contentStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ]

    }()

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

    // MARK: - Configuration

    override func configureCell() {
        super.configureCell()

        containerView.addSubview(contentStack)
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate(contentStackViewConstraints)
        
        super.addContent(rootView: containerView)
    }

    // MARK: - Updates

    override func updateColors() {
        super.updateColors()

        deletedMessageView.updateColors()
        messageDateAndStateView.updateColors()
    }
}

// MARK: - Reusable

extension ChatViewDeletedMessageTableViewCell: Reusable { }

// MARK: - ChatViewMessageAction

extension ChatViewDeletedMessageTableViewCell: ChatViewMessageAction {

    func messageActions()
        -> (
            primaryActions: [ChatViewMessageActionProvider.MessageAction],
            generalActions: [ChatViewMessageActionProvider.MessageAction]
        )? {

        guard let message = deletedMessageAndNeighbors?.message else {
            return nil
        }

        typealias Provider = ChatViewMessageActionProvider
        
        let detailAction = Provider.detailsAction {
            self.chatViewTableViewCellDelegate?.showDetails(for: message.objectID)
        }
            
        let selectHandler = Provider.selectAction {
            self.chatViewTableViewCellDelegate?.startMultiselect(with: message.objectID)
        }
        
        // Delete
        let willDelete = {
            self.chatViewTableViewCellDelegate?.willDeleteMessage(with: message.objectID)
        }
        
        let didDelete = {
            self.chatViewTableViewCellDelegate?.didDeleteMessages()
        }
        
        let deleteAction = Provider.deleteAction(
            message: message,
            willDelete: willDelete,
            didDelete: didDelete,
            popOverSource: chatBubbleView
        )
        
        // Build menu
        return ([], [detailAction, selectHandler, deleteAction])
    }
}
