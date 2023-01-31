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

import CocoaLumberjackSwift
import ThreemaFramework
import UIKit

/// Display sticker messages
final class ChatViewStickerMessageTableViewCell: ChatViewBaseTableViewCell, MeasurableCell {

    static var sizingCell = ChatViewStickerMessageTableViewCell()
    
    override var bubbleBackgroundColor: UIColor {
        .clear
    }
    
    override var selectedBubbleBackgroundColor: UIColor {
        .clear
    }
    
    override var nameLabelBottomInset: Double {
        0.0
    }

    /// Sticker message to display
    ///
    /// Reset it when the message had any changes to update data shown in the views (e.g. date or status symbol).
    var stickerMessageAndNeighbors: (message: StickerMessage, neighbors: ChatViewDataSource.MessageNeighbors)? {
        didSet {
            updateCell(for: stickerMessageAndNeighbors?.message)
            
            super.setMessage(
                to: stickerMessageAndNeighbors?.message,
                with: stickerMessageAndNeighbors?.neighbors
            )
        }
    }
    
    // MARK: - Views & constraints

    private lazy var thumbnailTapView = MessageThumbnailTapView { [weak self] in
        self?.chatViewTableViewCellDelegate?.didTap(message: self?.stickerMessageAndNeighbors?.message, in: self)
    }
    
    private lazy var rootView = UIView()

    // MARK: - Configuration
    
    override func configureCell() {
        super.configureCell()
        
        rootView.addSubview(thumbnailTapView)
        
        thumbnailTapView.translatesAutoresizingMaskIntoConstraints = false
        
        // This adds the margin to the chat bubble border
        rootView.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: -ChatViewConfiguration.Thumbnail.defaultMargin,
            leading: -ChatViewConfiguration.Thumbnail.defaultMargin,
            bottom: -ChatViewConfiguration.Thumbnail.defaultMargin,
            trailing: -ChatViewConfiguration.Thumbnail.defaultMargin
        )
        
        NSLayoutConstraint.activate([
            thumbnailTapView.layoutMarginsGuide.topAnchor.constraint(equalTo: rootView.topAnchor),
            thumbnailTapView.layoutMarginsGuide.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            thumbnailTapView.layoutMarginsGuide.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            thumbnailTapView.layoutMarginsGuide
                .bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
        ])
        
        super.addContent(rootView: rootView)
    }
    
    // MARK: - Updates
    
    private func updateCell(for stickerMessage: StickerMessage?) {
        // By accepting an optional the data is automatically reset when the text message is set to `nil`
        thumbnailTapView.thumbnailDisplayMessage = stickerMessage
    }
    
    override func updateColors() {
        super.updateColors()
        thumbnailTapView.updateColors()
    }
    
    override func highlightTappableAreasOfCell(_ highlight: Bool) {
        // Do nothing
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)

        thumbnailTapView.isUserInteractionEnabled = !editing
    }
}

// MARK: - ContextMenuAction

extension ChatViewStickerMessageTableViewCell: ContextMenuAction {
    
    func buildContextMenu(at indexPath: IndexPath) -> UIContextMenuConfiguration? {
       
        guard let message = stickerMessageAndNeighbors?.message, let data = message.blobGet() else {
            return nil
        }

        typealias Provider = ChatViewContextMenuActionProvider
        var menuItems = [UIAction]()
        
        // Speak
        var speakText = message.fileMessageType.localizedDescription
        if let caption = message.caption {
            speakText += ", " + caption
        }
        
        // Share
        let shareItems = [MessageActivityItem(for: message)]
        
        // Copy
        // In the new chat view we always copy the data, regardless if it has a caption because the text can be selected itself.
        let copyHandler = {
            guard !MDMSetup(setup: false).disableShareMedia() else {
                fatalError()
            }
            
            switch message.fileMessageType {
            case .sticker, .animatedSticker:
                guard let image = UIImage(data: data) else {
                    DDLogError("[CV CxtMenu] Could not copy sticker")
                    NotificationPresenterWrapper.shared.present(type: .copyError)
                    return
                }
                UIPasteboard.general.image = image
                NotificationPresenterWrapper.shared.present(type: .copySuccess)

            default:
                DDLogError("[CV CxtMenu] Message has invalid type.")
            }
        }
        
        // Quote
        let quoteHandler = {
            guard let chatViewTableViewCellDelegate = self.chatViewTableViewCellDelegate else {
                DDLogError("[CV CxtMenu] Could not show quote view because the delegate was nil.")
                return
            }
            
            guard let message = message as? QuoteMessage else {
                DDLogError("[CV CxtMenu] Could not show quote view because the message is not a quote message.")
                return
            }
            
            chatViewTableViewCellDelegate.showQuoteView(message: message)
        }
        
        // Save
        let albumManager = AlbumManager.shared
        let saveHandler = {
            guard !MDMSetup(setup: false).disableShareMedia() else {
                fatalError()
            }
            
            switch message.fileMessageType {
            case .sticker, .animatedSticker:
                guard let image = UIImage(data: data) else {
                    NotificationPresenterWrapper.shared.present(type: .saveError)
                    return
                }
                albumManager.save(image: image)
            default:
                DDLogError("[CV CxtMenu] Message has invalid type.")
            }
        }
        
        let saveAction = Provider.saveAction(handler: saveHandler)
        
        // Details
        let detailsHandler = {
            self.chatViewTableViewCellDelegate?.showDetails(for: message.objectID)
        }
        
        // Edit
        let editHandler = {
            self.chatViewTableViewCellDelegate?.startMultiselect()
        }
        
        let defaultActions = Provider.defaultActions(
            message: message,
            speakText: speakText,
            shareItems: shareItems,
            activityViewAnchor: contentView,
            copyHandler: copyHandler,
            quoteHandler: quoteHandler,
            detailsHandler: detailsHandler,
            editHandler: editHandler
        )
        
        // Build menu
        menuItems.append(contentsOf: defaultActions)
        
        // Save action is inserted before default action, depending if ack/dec is possible at a different position
        if !MDMSetup(setup: false).disableShareMedia() {
            if message.isUserAckEnabled {
                menuItems.insert(saveAction, at: 2)
            }
            else {
                menuItems.insert(saveAction, at: 0)
            }
        }
        
        let menu = UIMenu(children: menuItems)
        
        return UIContextMenuConfiguration(identifier: indexPath as NSCopying, previewProvider: nil) { _ in
            menu
        }
    }
}

// MARK: - Reusable

extension ChatViewStickerMessageTableViewCell: Reusable { }
