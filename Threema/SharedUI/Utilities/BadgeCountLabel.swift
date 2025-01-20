//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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

class BadgeCountLabel: UILabel {
    
    override var intrinsicContentSize: CGSize {
        var contentSize = super.intrinsicContentSize
        contentSize.height = 20
        
        if contentSize.width < 20 {
            contentSize.width = 20
        }
        else if contentSize.width > 20 {
            contentSize.width += 10
        }
        
        return contentSize
    }

    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLabel()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLabel()
    }
    
    convenience init() {
        self.init(frame: .zero)
    }
    
    override func drawText(in rect: CGRect) {
        let insets = UIEdgeInsets.zero
        super.drawText(in: rect.inset(by: insets))
    }
    
    public func updateColors() {
        backgroundColor = .red
        textColor = .white
        highlightedTextColor = .white
    }
    
    private func configureLabel() {
        font = UIFont.systemFont(ofSize: 13)
        updateColors()
        
        numberOfLines = 1
        textAlignment = .center
        translatesAutoresizingMaskIntoConstraints = false
        adjustsFontForContentSizeCategory = false
        
        layer.masksToBounds = true
        layer.cornerCurve = .continuous
        layer.cornerRadius = 10
    }
}
