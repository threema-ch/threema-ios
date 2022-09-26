//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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

// If you have a new cell you need to add it in 3 places: (also see Step 1 - 3 comments below)
//  1. Register in `registerCells(in:)`
//  2. Dequeue, assign message and return in `cell(for:in:at:)`
//  3. Assign and load sizing cell in `estimatedCellHeight(for:with:)`

// MARK: - Register and load cells

/// Register, load and configure all cells for the chat view
struct ChatViewCellProvider {
    /// Register all needed cells in provided table view
    /// - Parameter tableView: Table view to register cells on
    static func registerCells(in tableView: UITableView) {
        // Placeholder for missing cells
        tableView.registerCell(ChatViewPlaceholderTableViewCell.self)
        
        tableView.registerCell(ChatViewDebugFileMessageStatesTableViewCell.self)
        
        tableView.registerCell(ChatViewTextMessageTableViewCell.self)
        tableView.registerCell(ChatViewLocationMessageTableViewCell.self)
        tableView.registerCell(ChatViewImageMessageTableViewCell.self)
        tableView.registerCell(ChatViewStickerMessageTableViewCell.self)
        tableView.registerCell(ChatViewFileMessageTableViewCell.self)
        tableView.registerCell(ChatViewCallSystemMessageTableViewCell.self)
        tableView.registerCell(ChatViewSystemMessageTableViewCell.self)
        tableView.registerCell(ChatViewBallotMessageTableViewCell.self)
        // Step 1
    }
    
    /// Adds possibility to handle delegates of a specific cell
    weak var chatViewTableViewCellDelegate: ChatViewTableViewCellDelegate?
    
    /// Get a reusable cell for the passed message
    /// - Parameters:
    ///   - message: Message to get cell for
    ///   - tableView: Table view to load cell on
    ///   - indexPath: Index path of message
    /// - Returns: Reusable cell for the provided message
    func cell(for message: BaseMessage, in tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        
        switch message {
            
        case let textMessage as TextMessage:
            let cell: ChatViewTextMessageTableViewCell = tableView.dequeueCell(for: indexPath)
            cell.textMessage = textMessage
            cell.chatViewTableViewCellDelegate = chatViewTableViewCellDelegate
            return cell
        
        case let locationMessage as LocationMessage:
            let cell: ChatViewLocationMessageTableViewCell = tableView.dequeueCell(for: indexPath)
            cell.locationMessage = locationMessage
            cell.chatViewTableViewCellDelegate = chatViewTableViewCellDelegate
            return cell

        case let fileMessageProvider as FileMessageProvider:
            switch fileMessageProvider.fileMessageType {
            case let .image(imageMessage):
                let cell: ChatViewImageMessageTableViewCell = tableView.dequeueCell(for: indexPath)
                cell.imageMessage = imageMessage
                cell.chatViewTableViewCellDelegate = chatViewTableViewCellDelegate
                return cell
            case let .sticker(stickerMessage):
                let cell: ChatViewStickerMessageTableViewCell = tableView.dequeueCell(for: indexPath)
                cell.stickerMessage = stickerMessage
                cell.chatViewTableViewCellDelegate = chatViewTableViewCellDelegate
                return cell
            case .animatedImage:
                fatalError("Not implemented")
            case .animatedSticker:
                fatalError("Not implemented")
            case .video:
                fatalError("Not implemented")
            case .audio:
                fatalError("Not implemented")
            case let .file(fileMessage):
                let cell: ChatViewFileMessageTableViewCell = tableView.dequeueCell(for: indexPath)
                cell.fileMessage = fileMessage
                cell.chatViewTableViewCellDelegate = chatViewTableViewCellDelegate
                return cell
            case let .placeholder(fileMessageEntity):
                let cell: ChatViewDebugFileMessageStatesTableViewCell = tableView.dequeueCell(for: indexPath)
                cell.fileMessageEntity = fileMessageEntity
                cell.chatViewTableViewCellDelegate = chatViewTableViewCellDelegate
                return cell
            }
            
        case let systemMessage as SystemMessage:
            switch systemMessage.systemMessageType {
            case .callMessage:
                let cell: ChatViewCallSystemMessageTableViewCell = tableView.dequeueCell(for: indexPath)
                cell.callMessage = systemMessage
                cell.chatViewTableViewCellDelegate = chatViewTableViewCellDelegate
                return cell
            case .systemMessage:
                let cell: ChatViewSystemMessageTableViewCell = tableView.dequeueCell(for: indexPath)
                cell.systemMessage = systemMessage
                return cell
            }
            
        case let ballotMessage as BallotMessage:
            let cell: ChatViewBallotMessageTableViewCell = tableView.dequeueCell(for: indexPath)
            cell.ballotMessage = ballotMessage
            return cell
            
        // Step 2
            
        case let fileMessageEntity as FileMessageEntity:
            let cell: ChatViewDebugFileMessageStatesTableViewCell = tableView.dequeueCell(for: indexPath)
            cell.fileMessageEntity = fileMessageEntity
            cell.chatViewTableViewCellDelegate = chatViewTableViewCellDelegate
            return cell
            
        default:
            //            fatalError("Not supported message type")
            let cell: ChatViewPlaceholderTableViewCell = tableView.dequeueCell(for: indexPath)
            cell.message = message
            cell.chatViewTableViewCellDelegate = chatViewTableViewCellDelegate
            return cell
        }
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
    static func estimatedCellHeight(for message: BaseMessage, with width: CGFloat) -> CGFloat {
        let measurableCell: MeasurableCell
        
        switch message {
            
        case let textMessage as TextMessage:
            ChatViewTextMessageTableViewCell.sizingCell.textMessage = textMessage
            measurableCell = ChatViewTextMessageTableViewCell.sizingCell
            
        case let locationMessage as LocationMessage:
            ChatViewLocationMessageTableViewCell.sizingCell.locationMessage = locationMessage
            measurableCell = ChatViewLocationMessageTableViewCell.sizingCell
            
        case let fileMessageProvider as FileMessageProvider:
            switch fileMessageProvider.fileMessageType {
            case let .image(imageMessage):
                ChatViewImageMessageTableViewCell.sizingCell.imageMessage = imageMessage
                measurableCell = ChatViewImageMessageTableViewCell.sizingCell
            case let .sticker(stickerMessage):
                ChatViewStickerMessageTableViewCell.sizingCell.stickerMessage = stickerMessage
                measurableCell = ChatViewStickerMessageTableViewCell.sizingCell
            case .animatedImage:
                fatalError("Not implemented")
            case .animatedSticker:
                fatalError("Not implemented")
            case .video:
                fatalError("Not implemented")
            case .audio:
                fatalError("Not implemented")
            case let .file(fileMessage):
                ChatViewFileMessageTableViewCell.sizingCell.fileMessage = fileMessage
                measurableCell = ChatViewFileMessageTableViewCell.sizingCell
            case let .placeholder(fileMessageEntity):
                ChatViewDebugFileMessageStatesTableViewCell.sizingCell.fileMessageEntity = fileMessageEntity
                measurableCell = ChatViewDebugFileMessageStatesTableViewCell.sizingCell
            }
                
        case let systemMessage as SystemMessage:
            // Differentiate between CallMessages and other SystemMessages
            switch systemMessage.systemMessageType {
            case .callMessage:
                ChatViewCallSystemMessageTableViewCell.sizingCell.callMessage = systemMessage
                measurableCell = ChatViewCallSystemMessageTableViewCell.sizingCell
            case .systemMessage:
                ChatViewSystemMessageTableViewCell.sizingCell.systemMessage = systemMessage
                measurableCell = ChatViewSystemMessageTableViewCell.sizingCell
            }
            
        case let ballotMessage as BallotMessage:
            ChatViewBallotMessageTableViewCell.sizingCell.ballotMessage = ballotMessage
            measurableCell = ChatViewBallotMessageTableViewCell.sizingCell
            
        // Step 3
            
        case let fileMessageEntity as FileMessageEntity:
            ChatViewDebugFileMessageStatesTableViewCell.sizingCell.fileMessageEntity = fileMessageEntity
            measurableCell = ChatViewDebugFileMessageStatesTableViewCell.sizingCell
            
        default:
            //            fatalError("Not supported message type")
            ChatViewPlaceholderTableViewCell.sizingCell.message = message
            measurableCell = ChatViewPlaceholderTableViewCell.sizingCell
        }
        
        let size = CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
        
        // This is an expensive call, because it creates and destroys a full Auto Layout "engine" just for this call (see WWDC 18: High Performance Auto Layout)
        let cellSize = measurableCell.systemLayoutSizeFitting(
            size,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .defaultLow
        )
        
        return cellSize.height
    }
}
