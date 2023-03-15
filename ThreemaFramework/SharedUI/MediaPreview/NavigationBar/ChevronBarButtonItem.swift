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

extension ChevronBarButtonItem {
    struct Configuration {
        let minimumTouchTargetWidth: CGFloat = 44
        let offsetCorrection: CGFloat = 11
    }
}

/// Custom UIButton to replicate an UIBarButtonItem initialized with barButtonSystemItem and .close,
/// but with an chevron.backward.circle.fill icon. This is based off of the BallotWithOpenCountButton.swift class.
///
class ChevronBarButtonItem: UIButton {
    
    // MARK: - Public interface
    
    /// Ready to use left bar button item to use as a button in a navigation bar
    ///
    /// To align the button correctly as an right bar button item in a navigation bar some tweaks are need such that the button appears
    /// like a default bat button item.
    ///
    /// - Returns: Ready to use right bar button items array
    func asLeftBarButtonItem() -> [UIBarButtonItem] {
        let barButtonItem = UIBarButtonItem(customView: self)
        
        // This breaks for right bar button items if `configuration.offsetCorrection` > 8
        // Left bar button items do not seem to be affected
        let spacer = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        spacer.width = buttonConfiguration.offsetCorrection
        
        return [barButtonItem, spacer]
    }
    
    // MARK: - Private properties
    
    private let buttonConfiguration = ChevronBarButtonItem.Configuration()
    
    private lazy var highlightAnimator = UIViewPropertyAnimator.barButtonHighlightAnimator(for: self)
    
    // MARK: - Initialization
    
    required init(target: Any?, action selector: Selector) {
        super.init(frame: .zero)
        
        addTarget(target, action: selector, for: .touchUpInside)
        
        configureButton()
    }
    
    @available(*, deprecated, message: "Use init(with: UInt)")
    override init(frame: CGRect) {
        fatalError("Use init(with: UInt)")
    }
    
    @available(*, deprecated, message: "Use init(with: UInt)")
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configureButton() {
        // Using the tintColor property takes the default iOS tint color instead of ours
        let image = ChevronBarButtonItem.drawImage()
        setImage(image, for: .normal)
        imageView?.contentMode = .scaleAspectFill
        adjustsImageWhenHighlighted = false
        
        updateAccessibilityLabel()
    }
    
    public static func drawImage() -> UIImage {
        ChevronBackCircleImage.get()
    }
    
    private func updateAccessibilityLabel() {
        accessibilityLabel = BundleUtil.localizedString(forKey: "back")
    }
    
    // MARK: - Destruction
    
    deinit {
        highlightAnimator.stopAnimation(true)
    }
    
    // MARK: - Button interaction
    
    override var isHighlighted: Bool {
        didSet {
            guard isHighlighted != oldValue else {
                return
            }
            
            // Do not pause animation for UI tests, it will break the test
            if !ProcessInfoHelper.isRunningForScreenshots {
                highlightAnimator.pauseAnimation()
            }
            
            if isHighlighted {
                highlightAnimator.isReversed = false
                highlightAnimator.startAnimation()
            }
            else {
                highlightAnimator.isReversed = true
                highlightAnimator.startAnimation()
            }
        }
    }
    
    // MARK: - Workaround

    // Part of workaround to fix alignment of `UIBarButtonItem` with custom view (see class documentation for details)
    
    override var intrinsicContentSize: CGSize {
        // Try to set minimum width with constraints if we want to support different sized icons
        CGSize(
            width: buttonConfiguration.minimumTouchTargetWidth - buttonConfiguration.offsetCorrection,
            height: UIView.layoutFittingExpandedSize.height
        )
    }
    
    override var alignmentRectInsets: UIEdgeInsets {
        UIEdgeInsets(top: 0, left: buttonConfiguration.offsetCorrection, bottom: 0, right: 0)
    }
    
    override var translatesAutoresizingMaskIntoConstraints: Bool {
        get {
            false
        }
        set {
            super.translatesAutoresizingMaskIntoConstraints = newValue
        }
    }
}
