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

import UIKit

/// Show debug info in a text view for message details
final class ChatViewMessageDetailsDebugInfoTableViewCell: ThemedCodeTableViewCell {
    
    var debugText: String? {
        didSet {
            debugTextView.text = debugText
        }
    }
    
    private lazy var debugTextView: UITextView = {
        let textView = UITextView()
        
        textView.isScrollEnabled = false
        textView.isEditable = false
        
        return textView
    }()
    
    override func configureCell() {
        super.configureCell()

        selectionStyle = .none
        
        directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 5,
            leading: 5,
            bottom: 5,
            trailing: 5
        )
        
        contentView.addSubview(debugTextView)
        debugTextView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            debugTextView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            debugTextView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            debugTextView.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
            debugTextView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
        ])
    }
    
    override func updateColors() {
        super.updateColors()
        
        debugTextView.backgroundColor = .secondarySystemGroupedBackground
    }
}

// MARK: - Reusable

extension ChatViewMessageDetailsDebugInfoTableViewCell: Reusable { }
