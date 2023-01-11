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

import UIKit

/// Message content stack with default insets
final class DefaultMessageContentStackView: UIStackView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureStackView()
    }
        
    required init(coder: NSCoder) {
        super.init(coder: coder)
        configureStackView()
    }
    
    convenience init() {
        self.init(frame: .zero)
    }
    
    // The super implementation of this initializer cannot be overridden, thus we implement it ourselves.
    convenience init(arrangedSubviews views: [UIView]) {
        self.init()
        
        for view in views {
            addArrangedSubview(view)
        }
    }
    
    private func configureStackView() {
        axis = .vertical
        spacing = ChatViewConfiguration.Content.contentAndMetadataSpace
        isLayoutMarginsRelativeArrangement = true
    }
}
