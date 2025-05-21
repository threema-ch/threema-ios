//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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

// If you have a new cell you need to add it in 4 places: (also see Step 1 - 4 comments below)
//  1. Register in `registerCells(in:)`
//  2. Dequeue, assign message and return in `cell(for:in:at:)`
//  3. Assign and load sizing cell in `estimatedCellHeight(for:with:)`

// MARK: - Register and load cells

/// Register, load and configure all cells for the chat view
struct ChatViewCellProvider {
    
    /// Adds possibility to handle delegates of a specific cell
    weak var chatViewTableViewCellDelegate: ChatViewTableViewCellDelegateProtocol?
    
    /// Delegate to handle Audio Message cell interactions
    weak var chatViewTableViewVoiceMessageCellDelegate: ChatViewTableViewVoiceMessageCellDelegateProtocol?
    
    // MARK: - Registration
    
    private enum CellDirection {
        case incoming
        case outgoing
    }
    
    /// Register all needed cells in provided table view
    /// - Parameter tableView: Table view to register cells on
    static func registerCells(in tableView: UITableView) {
        
        // Register cells with different reuse identifiers for incoming and outgoing messages to avoid flickering when
        // an outgoing cell is reused as incoming and vice versa
        ChatViewCellProvider.registerIncomingOutgoingCells(ChatViewDeletedMessageTableViewCell.self, in: tableView)
        ChatViewCellProvider.registerIncomingOutgoingCells(ChatViewTextMessageTableViewCell.self, in: tableView)
        ChatViewCellProvider.registerIncomingOutgoingCells(ChatViewLocationMessageTableViewCell.self, in: tableView)
        ChatViewCellProvider.registerIncomingOutgoingCells(
            ChatViewThumbnailDisplayMessageTableViewCell.self,
            in: tableView
        )
        ChatViewCellProvider.registerIncomingOutgoingCells(
            ChatViewAnimatedImageMessageTableViewCell.self,
            in: tableView
        )
        ChatViewCellProvider.registerIncomingOutgoingCells(ChatViewVoiceMessageTableViewCell.self, in: tableView)
        ChatViewCellProvider.registerIncomingOutgoingCells(ChatViewFileMessageTableViewCell.self, in: tableView)
        ChatViewCellProvider.registerIncomingOutgoingCells(ChatViewBallotMessageTableViewCell.self, in: tableView)
        ChatViewCellProvider.registerIncomingOutgoingCells(ChatViewCallSystemMessageTableViewCell.self, in: tableView)
        
        // Register other cells
        tableView.registerCell(ChatViewStickerMessageTableViewCell.self)
        tableView.registerCell(ChatViewAnimatedStickerMessageTableViewCell.self)
        tableView.registerCell(ChatViewSystemMessageTableViewCell.self)
        tableView.registerCell(ChatViewWorkConsumerInfoSystemMessageTableViewCell.self)
        tableView.registerCell(ChatViewUnreadMessageLineCell.self)
        tableView.registerCell(ChatViewTypingIndicatorTableViewCell.self)
        
        tableView.registerCell(ChatViewCloseToZeroHeightTableViewCell.self)
        
        // Step 1
    }
    
    private static func registerIncomingOutgoingCells<CellType: UITableViewCell>(
        _ cell: CellType.Type,
        in tableView: UITableView
    ) where CellType: Reusable {
        tableView.register(cell, forCellReuseIdentifier: "\(CellType.reuseIdentifier)-\(CellDirection.incoming)")
        tableView.register(cell, forCellReuseIdentifier: "\(CellType.reuseIdentifier)-\(CellDirection.outgoing)")
    }
    
    // MARK: - Reusing
    
    /// Get a reusable cell for the passed message
    /// - Parameters:
    ///   - message: Message to get cell for
    ///   - tableView: Table view to load cell on
    ///   - indexPath: Index path of message
    /// - Returns: Reusable cell for the provided message
    func cell(
        for message: BaseMessageEntity,
        with neighbors: ChatViewDataSource.MessageNeighbors,
        in tableView: UITableView,
        at indexPath: IndexPath
    ) -> UITableViewCell {

        guard message.deletedAt == nil else {
            let cell: ChatViewDeletedMessageTableViewCell = ChatViewCellProvider.dequeueIncomingOutgoingCell(
                for: indexPath,
                and: message,
                in: tableView
            )
            cell.deletedMessageAndNeighbors = (message, neighbors)
            cell.chatViewTableViewCellDelegate = chatViewTableViewCellDelegate
            return cell
        }

        switch message {
            
        case let textMessage as TextMessageEntity:
            let cell: ChatViewTextMessageTableViewCell = ChatViewCellProvider.dequeueIncomingOutgoingCell(
                for: indexPath,
                and: message,
                in: tableView
            )
            cell.textMessageAndNeighbors = (textMessage, neighbors)
            cell.chatViewTableViewCellDelegate = chatViewTableViewCellDelegate
            return cell

        case let fileMessageProvider as FileMessageProvider:
            switch fileMessageProvider.fileMessageType {
                
            case let .image(imageMessage):
                let cell: ChatViewThumbnailDisplayMessageTableViewCell = ChatViewCellProvider
                    .dequeueIncomingOutgoingCell(
                        for: indexPath,
                        and: message,
                        in: tableView
                    )
                cell.thumbnailDisplayMessageAndNeighbors = (imageMessage, neighbors)
                cell.chatViewTableViewCellDelegate = chatViewTableViewCellDelegate
                return cell
                
            case let .sticker(stickerMessage):
                let cell: ChatViewStickerMessageTableViewCell = tableView.dequeueCell(for: indexPath)
                cell.stickerMessageAndNeighbors = (stickerMessage, neighbors)
                cell.chatViewTableViewCellDelegate = chatViewTableViewCellDelegate
                return cell
                
            case let .animatedImage(animatedImageMessage):
                let cell: ChatViewAnimatedImageMessageTableViewCell = ChatViewCellProvider.dequeueIncomingOutgoingCell(
                    for: indexPath,
                    and: message,
                    in: tableView
                )
                cell.animatedImageMessageAndNeighbors = (animatedImageMessage, neighbors)
                cell.chatViewTableViewCellDelegate = chatViewTableViewCellDelegate
                return cell
                
            case let .animatedSticker(animatedStickerMessage):
                let cell: ChatViewAnimatedStickerMessageTableViewCell = tableView.dequeueCell(for: indexPath)
                cell.animatedStickerMessageAndNeighbors = (animatedStickerMessage, neighbors)
                cell.chatViewTableViewCellDelegate = chatViewTableViewCellDelegate
                return cell
                
            case let .video(videoMessage):
                let cell: ChatViewThumbnailDisplayMessageTableViewCell = ChatViewCellProvider
                    .dequeueIncomingOutgoingCell(
                        for: indexPath,
                        and: message,
                        in: tableView
                    )
                cell.thumbnailDisplayMessageAndNeighbors = (videoMessage, neighbors)
                cell.chatViewTableViewCellDelegate = chatViewTableViewCellDelegate
                return cell
                
            case let .voice(voiceMessage):
                let cell: ChatViewVoiceMessageTableViewCell = ChatViewCellProvider.dequeueIncomingOutgoingCell(
                    for: indexPath,
                    and: message,
                    in: tableView
                )
                cell.voiceMessageAndNeighbors = (voiceMessage, neighbors)
                cell.chatViewTableViewCellDelegate = chatViewTableViewCellDelegate
                cell.voiceMessageCellDelegate = chatViewTableViewVoiceMessageCellDelegate
                return cell
                
            case let .file(fileMessage):
                let cell: ChatViewFileMessageTableViewCell = ChatViewCellProvider.dequeueIncomingOutgoingCell(
                    for: indexPath,
                    and: message,
                    in: tableView
                )
                cell.fileMessageAndNeighbors = (fileMessage, neighbors)
                cell.chatViewTableViewCellDelegate = chatViewTableViewCellDelegate
                return cell
            }
            
        case let locationMessage as LocationMessageEntity:
            let cell: ChatViewLocationMessageTableViewCell = ChatViewCellProvider.dequeueIncomingOutgoingCell(
                for: indexPath,
                and: message,
                in: tableView
            )
            cell.locationMessageAndNeighbors = (locationMessage, neighbors)
            cell.chatViewTableViewCellDelegate = chatViewTableViewCellDelegate
            return cell
            
        case let ballotMessage as BallotMessageEntity:
            let cell: ChatViewBallotMessageTableViewCell = ChatViewCellProvider.dequeueIncomingOutgoingCell(
                for: indexPath,
                and: message,
                in: tableView
            )
            cell.ballotMessageAndNeighbors = (ballotMessage, neighbors)
            cell.chatViewTableViewCellDelegate = chatViewTableViewCellDelegate
            return cell
            
        case let systemMessage as SystemMessageEntity:
            switch systemMessage.systemMessageType {
            case .callMessage:
                let cell: ChatViewCallSystemMessageTableViewCell = ChatViewCellProvider.dequeueIncomingOutgoingCell(
                    for: indexPath,
                    and: systemMessage,
                    in: tableView
                )
                cell.callMessageAndNeighbors = (systemMessage, neighbors)
                cell.chatViewTableViewCellDelegate = chatViewTableViewCellDelegate
                return cell
                
            case .systemMessage:
                let cell: ChatViewSystemMessageTableViewCell = tableView.dequeueCell(for: indexPath)
                cell.systemMessageAndNeighbors = (systemMessage, neighbors)
                cell.chatViewTableViewCellDelegate = chatViewTableViewCellDelegate
                return cell
                
            case .workConsumerInfo:
                let cell: ChatViewWorkConsumerInfoSystemMessageTableViewCell = tableView.dequeueCell(for: indexPath)
                cell.systemMessage = systemMessage
                return cell
            }
            
            // Step 2
            
        default:
            fatalError("Not supported message type: \(message.loggingDescription)")
        }
    }
    
    private static func dequeueIncomingOutgoingCell<CellType: UITableViewCell>(
        for indexPath: IndexPath,
        and message: BaseMessageEntity,
        in tableView: UITableView
    ) -> CellType where CellType: Reusable {
        let reuseIdentifierExtension: CellDirection = message.isOwnMessage ? .incoming : .outgoing
        
        let cell = tableView.dequeueReusableCell(
            withIdentifier: "\(CellType.reuseIdentifier)-\(reuseIdentifierExtension)",
            for: indexPath
        )
        
        guard let castedCell = cell as? CellType else {
            fatalError("Unable to cast reuse cell with identifier \(CellType.reuseIdentifier) to \(CellType.self)")
        }
        
        return castedCell
    }
    
    func unreadMessageLine(
        with unreadMessagesCount: Int,
        in tableView: UITableView,
        at indexPath: IndexPath
    ) -> ChatViewUnreadMessageLineCell {
        let cell: ChatViewUnreadMessageLineCell = tableView.dequeueCell(for: indexPath)
        cell.chatViewTableViewCellDelegate = chatViewTableViewCellDelegate
        
        // Updating text
        let text = String.localizedStringWithFormat(
            #localize("unread_messages_line_with_count"),
            unreadMessagesCount
        )
        cell.text = text
        
        return cell
    }
    
    func typingIndicator(
        in tableView: UITableView,
        at indexPath: IndexPath
    ) -> ChatViewTypingIndicatorTableViewCell {
        tableView.dequeueCell(for: indexPath)
    }
    
    func closeToZeroHeightCell(
        in tableView: UITableView,
        at indexPath: IndexPath
    ) -> ChatViewCloseToZeroHeightTableViewCell {
        tableView.dequeueCell(for: indexPath)
    }
}

// MARK: - Measure cell height

/// Require cell to provide a sizing cell
protocol MeasurableCell: ThemedCodeTableViewCell {
    static var sizingCell: Self { get }
}

/// Load estimated cell sizes for messages
enum ChatViewCellSizeProvider {
    /// Estimates height for a message in a view with the provided width
    /// - Parameters:
    ///   - message: Message to estimate cell height for
    ///   - width: Width of table view this message cell is shown in
    /// - Returns: Estimated height
    static func estimatedCellHeight(
        for message: BaseMessageEntity,
        with neighbors: ChatViewDataSource.MessageNeighbors,
        and width: CGFloat
    ) -> CGFloat {
        let measurableCell: MeasurableCell

        if message.deletedAt == nil {
            switch message {

            case let textMessage as TextMessageEntity:
                ChatViewTextMessageTableViewCell.sizingCell.textMessageAndNeighbors = (
                    message: textMessage,
                    neighbors: neighbors
                )
                measurableCell = ChatViewTextMessageTableViewCell.sizingCell

            case let fileMessageProvider as FileMessageProvider:
                switch fileMessageProvider.fileMessageType {
                case let .image(imageMessage):
                    ChatViewThumbnailDisplayMessageTableViewCell.sizingCell.thumbnailDisplayMessageAndNeighbors = (
                        message: imageMessage,
                        neighbors: neighbors
                    )
                    measurableCell = ChatViewThumbnailDisplayMessageTableViewCell.sizingCell

                case let .sticker(stickerMessage):
                    ChatViewStickerMessageTableViewCell.sizingCell.stickerMessageAndNeighbors = (
                        stickerMessage,
                        neighbors
                    )
                    measurableCell = ChatViewStickerMessageTableViewCell.sizingCell

                case let .animatedImage(animatedImageMessage):
                    ChatViewAnimatedImageMessageTableViewCell.sizingCell.animatedImageMessageAndNeighbors = (
                        animatedImageMessage,
                        neighbors
                    )
                    measurableCell = ChatViewAnimatedImageMessageTableViewCell.sizingCell

                case let .animatedSticker(animatedStickerMessage):
                    ChatViewAnimatedStickerMessageTableViewCell.sizingCell.animatedStickerMessageAndNeighbors = (
                        animatedStickerMessage,
                        neighbors
                    )
                    measurableCell = ChatViewAnimatedStickerMessageTableViewCell.sizingCell

                case let .video(videoMessage):
                    ChatViewThumbnailDisplayMessageTableViewCell.sizingCell.thumbnailDisplayMessageAndNeighbors = (
                        videoMessage,
                        neighbors
                    )
                    measurableCell = ChatViewThumbnailDisplayMessageTableViewCell.sizingCell

                case .voice:
                    fatalError("Not implemented")

                case let .file(fileMessage):
                    ChatViewFileMessageTableViewCell.sizingCell.fileMessageAndNeighbors = (fileMessage, neighbors)
                    measurableCell = ChatViewFileMessageTableViewCell.sizingCell
                }

            case let locationMessage as LocationMessageEntity:
                ChatViewLocationMessageTableViewCell.sizingCell.locationMessageAndNeighbors = (
                    message: locationMessage,
                    neighbors: neighbors
                )
                measurableCell = ChatViewLocationMessageTableViewCell.sizingCell

            case let ballotMessage as BallotMessageEntity:
                ChatViewBallotMessageTableViewCell.sizingCell.ballotMessageAndNeighbors = (ballotMessage, neighbors)
                measurableCell = ChatViewBallotMessageTableViewCell.sizingCell

            case let systemMessage as SystemMessageEntity:
                // Differentiate between CallMessages and other SystemMessages
                switch systemMessage.systemMessageType {
                case .callMessage:
                    ChatViewCallSystemMessageTableViewCell.sizingCell.callMessageAndNeighbors = (
                        systemMessage,
                        neighbors
                    )
                    measurableCell = ChatViewCallSystemMessageTableViewCell.sizingCell
                case .systemMessage:
                    ChatViewSystemMessageTableViewCell.sizingCell.systemMessageAndNeighbors = (systemMessage, neighbors)
                    measurableCell = ChatViewSystemMessageTableViewCell.sizingCell
                case .workConsumerInfo:
                    ChatViewWorkConsumerInfoSystemMessageTableViewCell.sizingCell.systemMessage = systemMessage
                    measurableCell = ChatViewWorkConsumerInfoSystemMessageTableViewCell.sizingCell
                }

            // Step 3

            default:
                fatalError("Not supported message type: \(message.loggingDescription)")
            }
        }
        else {
            measurableCell = ChatViewDeletedMessageTableViewCell.sizingCell
        }

        let size = CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
        
        // This is an expensive call, because it creates and destroys a full Auto Layout "engine" just for this call
        // (see WWDC 18: High Performance Auto Layout)
        let cellSize = measurableCell.systemLayoutSizeFitting(
            size,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .defaultLow
        )
        
        return cellSize.height
    }
}
