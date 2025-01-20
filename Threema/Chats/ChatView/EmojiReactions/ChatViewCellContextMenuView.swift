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

class ChatViewCellContextMenuView: UIView {
    
    // MARK: - Subviews

    private let cellView: UIView
    private let reactionView: UIView
    private let reactionsManager: ReactionsManager?
    
    private let cellReactionViewSpacing = 8.0
   
    // MARK: - Lifecycle

    init(cellView: UIView, isOwnMessage: Bool, forHighlighting: Bool, reactionsManager: ReactionsManager?) {
        self.cellView = cellView
        self.reactionView = MessageReactionContextMenuUIView(
            forHighlighting: forHighlighting,
            isOwnMessage: isOwnMessage,
            reactionsManager: reactionsManager
        ).view

        self.reactionsManager = reactionsManager
        
        let biggerWidth = max(MessageReactionContextMenuView.frameWidth, cellView.frame.width)
        let maxSize = CGSize(
            width: biggerWidth,
            height: cellView.bounds.height + MessageReactionContextMenuView.frameHeight + cellReactionViewSpacing
        )
        
        super.init(frame: CGRect(origin: .zero, size: maxSize))
        
        configureView(isOwnMessage)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
    
    // MARK: - Configuration
    
    private func configureView(_ isOwnMessage: Bool) {
        backgroundColor = .clear
        
        cellView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cellView)
        
        reactionView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(reactionView)
        
        NSLayoutConstraint.activate([
            reactionView.topAnchor.constraint(equalTo: topAnchor),
            reactionView.bottomAnchor.constraint(equalTo: cellView.topAnchor, constant: -cellReactionViewSpacing),
            reactionView.widthAnchor.constraint(lessThanOrEqualToConstant: UIScreen.main.bounds.width),
            
            cellView.heightAnchor.constraint(equalToConstant: cellView.frame.height),
            cellView.widthAnchor.constraint(greaterThanOrEqualToConstant: cellView.frame.width),
            cellView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        if isOwnMessage {
            NSLayoutConstraint.activate([
                cellView.trailingAnchor.constraint(equalTo: trailingAnchor),
                reactionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
        }
        else {
            NSLayoutConstraint.activate([
                cellView.leadingAnchor.constraint(equalTo: leadingAnchor),
                reactionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            ])
        }
    }
}
