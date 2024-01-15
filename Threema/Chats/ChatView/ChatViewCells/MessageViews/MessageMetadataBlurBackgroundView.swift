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
    ///   - rootView: (Container) view to display on top of the background with `UIVibrancyEffect`
    ///   - nonVibrantRootView: (Container) view to display on top of the background and `rootView` without
    /// `UIVibrancyEffect`
    init(
        rootView: UIView,
        nonVibrantRootView: UIView? = nil
    ) {
        super.init(effect: blurEffect)
        
        configureView(with: rootView, nonVibrantRootView: nonVibrantRootView)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Configure
    
    private func configureView(with rootView: UIView, nonVibrantRootView: UIView?) {
        // All views have their constraints related to the `contentView`.
        func pinToContentView(_ view: UIView) {
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(
                    equalTo: contentView.topAnchor,
                    constant: ChatViewConfiguration.MetadataBackground.topAndBottomInset
                ),
                view.leadingAnchor.constraint(
                    equalTo: contentView.leadingAnchor,
                    constant: ChatViewConfiguration.MetadataBackground.leadingAndTrailingInset
                ),
                view.bottomAnchor.constraint(
                    equalTo: contentView.bottomAnchor,
                    constant: -ChatViewConfiguration.MetadataBackground.topAndBottomInset
                ),
                view.trailingAnchor.constraint(
                    equalTo: contentView.trailingAnchor,
                    constant: -ChatViewConfiguration.MetadataBackground.leadingAndTrailingInset
                ),
            ])
        }
        
        // Embed content into stack for easy vertical centering
        let rootStack = UIStackView(arrangedSubviews: [rootView])
        rootStack.alignment = .center
        
        // Layout
        vibrantEffectView.contentView.addSubview(rootStack)
        contentView.addSubview(vibrantEffectView)
        
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        vibrantEffectView.translatesAutoresizingMaskIntoConstraints = false
        
        pinToContentView(rootStack)
        pinToContentView(vibrantEffectView)

        // Add `nonVibrantRootView` not affected by the default vibrancy effects (such as change to monochrome)
        // made by `UIVibrancyEffect`
        if let nonVibrantRootView {
            let nonVibrantRootStack = UIStackView(arrangedSubviews: [nonVibrantRootView])
            nonVibrantRootStack.alignment = .center
            
            // No extra container is needed. The stack view does all the needed things to align correctly.
            
            contentView.addSubview(nonVibrantRootStack)
            nonVibrantRootStack.translatesAutoresizingMaskIntoConstraints = false
            pinToContentView(nonVibrantRootStack)
        }
        
        sizeConstraint.isActive = true
        
        // Corner radius
        layer.cornerRadius = ChatViewConfiguration.MetadataBackground.cornerRadius
        clipsToBounds = true
        
        if UIAccessibility.isReduceTransparencyEnabled || UIAccessibility.isDarkerSystemColorsEnabled {
            backgroundColor = Colors.backgroundChatBar
        }
    }
}
