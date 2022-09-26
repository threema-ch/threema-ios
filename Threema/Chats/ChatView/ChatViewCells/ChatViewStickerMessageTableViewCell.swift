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

/// Display sticker messages
final class ChatViewStickerMessageTableViewCell: ChatViewBaseTableViewCell, MeasurableCell {

    static var sizingCell = ChatViewStickerMessageTableViewCell()
    
    override var bubbleBackgroundColor: UIColor {
        .clear
    }

    /// Sticker message to display
    ///
    /// Reset it when the message had any changes to update data shown in the views (e.g. date or status symbol).
    var stickerMessage: StickerMessage? {
        didSet {
            super.setMessage(to: stickerMessage)
            updateCell(for: stickerMessage)
        }
    }
    
    // MARK: - Views & constraints
    
    private lazy var thumbnailButton = MessageThumbnailButton { _ in
        // TODO: (IOS-2590) Implement
        print("Thumbnail pressed")
    }
    
    private lazy var rootView = UIView()

    // MARK: - Configuration
    
    override func configureCell() {
        super.configureCell()
        
        rootView.addSubview(thumbnailButton)
        
        thumbnailButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            thumbnailButton.layoutMarginsGuide.topAnchor.constraint(equalTo: rootView.topAnchor),
            thumbnailButton.layoutMarginsGuide.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            thumbnailButton.layoutMarginsGuide.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            thumbnailButton.layoutMarginsGuide
                .bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
        ])
        
        super.addContent(rootView: rootView)
    }
    
    // MARK: - Updates
    
    private func updateCell(for stickerMessage: StickerMessage?) {
        // By accepting an optional the data is automatically reset when the text message is set to `nil`
        
        thumbnailButton.thumbnailDisplayMessage = stickerMessage
    }
}

// MARK: - Reusable

extension ChatViewStickerMessageTableViewCell: Reusable { }
