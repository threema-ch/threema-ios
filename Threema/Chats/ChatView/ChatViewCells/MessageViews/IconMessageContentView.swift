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

import UIKit

/// Message and Icon content stack with default insets
final class IconMessageContentView: UIView {
    
    // MARK: - Views & constraints
    
    private lazy var textStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = ChatViewConfiguration.Content.textAndSecondaryTextSpace
        
        return stackView
    }()
    
    /// Distance of icon center from leading side
    private lazy var iconXCenterLeadingDistance: CGFloat = {
        // Adapt for content size categories
        UIFontMetrics.default.scaledValue(for: ChatViewConfiguration.Content.defaultIconCenterInset)
    }()
    
    /// Offset of text label from leading side
    private lazy var textStackViewLeadingDistance: CGFloat = {
        // The text stack view is as far away from the symbol center as its center is form the leading edge plus the
        // space
        let offset = 2 * iconXCenterLeadingDistance // This is already scaled
        let scaledSpace = UIFontMetrics.default.scaledValue(
            for: ChatViewConfiguration.Content.defaultIconAndTextSpace
        )
        
        return offset + scaledSpace
    }()
    
    private let tapAction: () -> Void
    
    // MARK: - Lifecycle
    
    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError()
    }
    
    @available(*, unavailable)
    override init(frame: CGRect) {
        fatalError()
    }
    
    init(iconView: UIView, arrangedSubviews views: [UIView], tapAction: @escaping () -> Void) {
        self.tapAction = tapAction

        super.init(frame: .zero)
        
        let tapGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGestureRecognizer.minimumPressDuration = 0.0
        tapGestureRecognizer.delegate = self
        addGestureRecognizer(tapGestureRecognizer)
        
        // Fill TextViewStack
        textStackView.translatesAutoresizingMaskIntoConstraints = false
        for view in views {
            textStackView.addArrangedSubview(view)
        }
        addSubview(textStackView)
        
        // Add icon if needed and apply resulting constraints
        configureLayout(iconView: iconView)
    }
    
    // Adds subviews and applies constraints
    private func configureLayout(iconView: UIView) {
        
        // This adds the margin to the chat bubble border
        directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: -ChatViewConfiguration.Content.defaultTopBottomInset,
            leading: -ChatViewConfiguration.Content.defaultLeadingTrailingInset,
            bottom: -ChatViewConfiguration.Content.defaultTopBottomInset,
            trailing: -ChatViewConfiguration.Content.defaultLeadingTrailingInset
        )
        
        let textStackViewLeadingConstraint: NSLayoutConstraint

        // We only add the icon if user does not use accessibility fonts, and must set constraints accordingly
        if !traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            
            iconView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(iconView)
            
            NSLayoutConstraint.activate([
                iconView.firstBaselineAnchor.constraint(
                    equalTo: textStackView.firstBaselineAnchor
                ),
                iconView.centerXAnchor.constraint(
                    equalTo: leadingAnchor,
                    constant: iconXCenterLeadingDistance
                ),
            ])
            
            textStackViewLeadingConstraint = textStackView.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: textStackViewLeadingDistance
            )
        }
        else {
            textStackViewLeadingConstraint = textStackView.leadingAnchor.constraint(
                equalTo: leadingAnchor
            )
        }
        
        NSLayoutConstraint.activate([
            textStackView.topAnchor.constraint(
                equalTo: topAnchor
            ),
            textStackViewLeadingConstraint,
            textStackView.bottomAnchor.constraint(
                equalTo: bottomAnchor
            ),
            textStackView.trailingAnchor.constraint(
                equalTo: trailingAnchor
            ),
        ])
    }
    
    @objc func handleTap(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            tapAction()
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

// This resolves an issue where the gesture recognizer would infer with scrolling interactions
extension IconMessageContentView: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        if otherGestureRecognizer is UIPanGestureRecognizer {
            return true
        }
        return false
    }
    
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        if otherGestureRecognizer is UIPanGestureRecognizer {
            return true
        }
        return false
    }
}
