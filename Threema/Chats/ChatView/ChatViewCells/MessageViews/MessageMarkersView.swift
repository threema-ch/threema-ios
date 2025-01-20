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
import UIKit

final class MessageMarkersView: UIView {
    
    /// Message to show markers for
    ///
    /// Reset to update with current message information.
    var message: BaseMessage? {
        didSet {
            guard let message else {
                return
            }
            updateMarkers(for: message)
        }
    }
        
    // MARK: - Private properties

    private lazy var markerStarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .center
        imageView.image = UIImage(systemName: "star.fill")?.withTintColor(.systemYellow)
        imageView.preferredSymbolConfiguration = ChatViewConfiguration.MessageMetadata.symbolConfiguration
        imageView.tintColor = .systemYellow
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var markerStarConstraints: [NSLayoutConstraint] = [
        markerStarImageView.topAnchor.constraint(equalTo: topAnchor),
        markerStarImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
        markerStarImageView.bottomAnchor.constraint(equalTo: bottomAnchor),
        markerStarImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
    ]
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLayout()
    }
        
    convenience init() {
        self.init(frame: .zero)
    }
    
    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configureLayout() {
        addSubview(markerStarImageView)
    }
    
    // MARK: - Updates
    
    private func updateMarkers(for message: BaseMessage) {
        guard message.hasMarkers else {
            markerStarImageView.isHidden = true
            NSLayoutConstraint.deactivate(markerStarConstraints)
            return
        }
        
        NSLayoutConstraint.activate(markerStarConstraints)
        markerStarImageView.isHidden = false
    }
}
