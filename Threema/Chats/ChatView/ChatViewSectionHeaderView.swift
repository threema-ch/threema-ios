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

/// View for a chat view section header (i.e. day header)
final class ChatViewSectionHeaderView: UIView {

    private let dateLabel = ChatViewSectionHeaderLabel()
    
    // MARK: - Lifecycle
    
    init(text: String?) {
        super.init(frame: .zero)
        
        dateLabel.text = text
        dateLabel.accessibilityTraits = .header
        
        if UserSettings.shared().flippedTableView {
            self.transform = CGAffineTransform(scaleX: 1, y: -1)
        }
        
        configureView()
    }
    
    @available(*, unavailable)
    override init(frame: CGRect) {
        fatalError("Use init(text:)")
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Use init(text:)")
    }
    
    // MARK: - Configuration
    
    private func configureView() {
        
        addSubview(dateLabel)
        
        let topConstraint = dateLabel.topAnchor.constraint(
            equalTo: topAnchor,
            constant: ChatViewConfiguration.SectionHeader.defaultTopAndBottomInset
        )
        topConstraint.priority = .defaultHigh
        
        let bottomConstraint = dateLabel.bottomAnchor.constraint(
            equalTo: bottomAnchor,
            constant: -ChatViewConfiguration.SectionHeader.defaultTopAndBottomInset
        )
        bottomConstraint.priority = .defaultHigh
    
        NSLayoutConstraint.activate([
            topConstraint,
            bottomConstraint,
            dateLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            
            // Ideally we'd want to use `readableContentSize` instead of `safeAreaLayoutGuide` but if we do we run into a weird issue where
            // the width is zero, then a small value, a slightly smaller value and then the actual value again if the header view is not visible but we do a layout pass.
            dateLabel.widthAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.widthAnchor, multiplier: 0.8),
        ])
    }
}
