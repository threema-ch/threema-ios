//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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

extension CircleButton {
    struct Configuration {
        /// Diameter of circular button adjusted for current content size
        var scaledMediumSize: CGFloat {
            let defaultMediumSize: CGFloat = 52
            return UIFontMetrics.default.scaledValue(for: defaultMediumSize)
        }
    }
}

/// Circle button with an icon in the center and a background
///
/// Use as-is and provide all configuration during initialization. Using `UIButton` methods might lead to unexpected side-effects.
final class CircleButton: ThemedCodeButton {
    
    // Potential future improvements:
    // - Scale icon along with size
    // - Provide second `small` configuration
    // - Also change background when highlighted
    // - Define separate `Colors` property for background color independent of chat bubble color
    
    private let buttonConfiguration = Configuration()
    
    private lazy var sizeConstraint: NSLayoutConstraint = widthAnchor
        .constraint(equalToConstant: buttonConfiguration.scaledMediumSize)
    
    // MARK: - Lifecycle
    
    /// Create a new button
    ///
    /// - Parameters:
    ///   - sfSymbolName: Name of SF Symbol to show. Use just the SF Symbol name.
    ///                     You should put a semibold L variant into the asset catalog.
    ///   - accessibilityLabel: Description of the button action for accessibility users.
    ///   - action: Action called when the button is tapped.
    init(
        sfSymbolName: String,
        accessibilityLabel: String,
        action: @escaping Action
    ) {

        // Setting the actual frame size fixes an Auto Layout error that probably occurs when
        // there is no superview
        let initFrame = CGRect(
            x: 0, y: 0,
            width: buttonConfiguration.scaledMediumSize,
            height: buttonConfiguration.scaledMediumSize
        )
        
        super.init(frame: initFrame, action: action)
        
        configureButton(with: sfSymbolName)
        registerObservers()
        updateColors()
        updateSize()
        
        self.accessibilityLabel = accessibilityLabel
    }
    
    // MARK: - Configure
    
    private func configureButton(with sfSymbolName: String) {
        // Content
        let image = BundleUtil.imageNamed("\(sfSymbolName)_semibold.L")
        assert(image != nil, "SF Symbol: semibold & L required for '\(sfSymbolName)'")
        setImage(image, for: .normal)
                        
        // Layout
        NSLayoutConstraint.activate([
            sizeConstraint,
            heightAnchor.constraint(equalTo: widthAnchor),
        ])
    }
    
    private func registerObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentSizeCategoryDidChange),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
    }
    
    // MARK: - Updates
    
    override func updateColors() {
        super.updateColors()
        backgroundColor = Colors.backgroundCircleButton
    }
    
    private func updateSize() {
        sizeConstraint.constant = buttonConfiguration.scaledMediumSize
        layer.cornerRadius = buttonConfiguration.scaledMediumSize / 2
    }
    
    // MARK: - Notifications
    
    @objc private func contentSizeCategoryDidChange() {
        updateSize()
    }
}
