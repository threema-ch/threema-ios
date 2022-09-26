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

/// Blurry background view with rounded corners
final class MessageMetadataBlurBackgroundView: UIVisualEffectView {
        
    // MARK: - Views & constraints
    
    private lazy var sizeConstraint: NSLayoutConstraint = heightAnchor
        .constraint(greaterThanOrEqualToConstant: ChatViewConfiguration.MetadataBackground.cornerRadius * 2)
    
    // All the stuff to make it blurry and vibrant
    private let blurEffect = UIBlurEffect(style: .systemThinMaterial)
    private lazy var vibrantEffectView = UIVisualEffectView(
        effect: UIVibrancyEffect(blurEffect: blurEffect, style: .fill)
    )
    
    // MARK: - Lifecycle
    
    /// Create a new view
    ///
    /// - Parameters:
    ///   - rootView: (Container) view to display on top of the background
    init(
        rootView: UIView
    ) {
        super.init(effect: blurEffect)
        
        configureView(with: rootView)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Configure
    
    private func configureView(with rootView: UIView) {
        
        // Embed content into stack for easy vertical centering
        let rootStack = UIStackView(arrangedSubviews: [rootView])
        rootStack.alignment = .center
        
        // Layout
        
        vibrantEffectView.contentView.addSubview(rootStack)
        contentView.addSubview(vibrantEffectView)
        
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        vibrantEffectView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(
                equalTo: vibrantEffectView.topAnchor,
                constant: ChatViewConfiguration.MetadataBackground.topAndBottomInset
            ),
            rootStack.leadingAnchor.constraint(
                equalTo: vibrantEffectView.leadingAnchor,
                constant: ChatViewConfiguration.MetadataBackground.leadingAndTrailingInset
            ),
            rootStack.bottomAnchor.constraint(
                equalTo: vibrantEffectView.bottomAnchor,
                constant: -ChatViewConfiguration.MetadataBackground.topAndBottomInset
            ),
            rootStack.trailingAnchor.constraint(
                equalTo: vibrantEffectView.trailingAnchor,
                constant: -ChatViewConfiguration.MetadataBackground.leadingAndTrailingInset
            ),
            
            vibrantEffectView.topAnchor.constraint(equalTo: topAnchor),
            vibrantEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            vibrantEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),
            vibrantEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            sizeConstraint,
        ])
        
        // Corner radius
        layer.cornerRadius = ChatViewConfiguration.MetadataBackground.cornerRadius
        clipsToBounds = true
    }
}
