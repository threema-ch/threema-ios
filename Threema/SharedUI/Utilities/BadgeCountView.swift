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

import Foundation

final class BadgeCountView: UIView {
    
    // MARK: Views
    
    private lazy var badgeLabel = BadgeCountLabel()
    
    // MARK: - Lifecycle
    
    /// Create a badge view
    init() {
        super.init(frame: .zero)
        
        configureView()
        updateCountLabel(to: "")
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Configuration
    
    private func configureView() {
        
        translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(badgeLabel)

        NSLayoutConstraint.activate([
            badgeLabel.topAnchor.constraint(equalTo: topAnchor),
            badgeLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            badgeLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            badgeLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
            badgeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            badgeLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }
    
    public func updateColors() {
        badgeLabel.updateColors()
    }
        
    // MARK: - Updates
    
    /// Update count label
    /// - Parameter countString: String with the new count
    func updateCountLabel(to countString: String) {
        badgeLabel.text = countString
    }
}
