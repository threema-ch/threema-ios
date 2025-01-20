//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2025 Threema GmbH
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
import ThreemaMacros

class PlusButtonCollectionViewCell: UICollectionViewCell {
    @IBOutlet var imageView: UIImageView!
    func setup() {
        contentView.backgroundColor = .secondary
        imageView.image = UIImage(systemName: "plus")?.applying(symbolWeight: .semibold, symbolScale: .large)
            .withTint(.primary)
        
        layer.borderWidth = 2
        layer.cornerRadius = 5
        layer.borderColor = UIColor.systemGroupedBackground.cgColor
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        setup()
    }
    
    override var isAccessibilityElement: Bool {
        set { }
        get {
            true
        }
    }
    
    override var accessibilityLabel: String? {
        set { }
        get {
            #localize("media_preview_accessibility_plus_button")
        }
    }
    
    // CGColors have no automatic theme change built in, so we track it ourselves
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        guard traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle else {
            return
        }
        
        layer.borderColor = UIColor.systemGroupedBackground.cgColor
    }
}
