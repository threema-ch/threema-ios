//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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

import ThreemaFramework
import UIKit

/// Custom view to show a ballot icon with an open ballots count badge
///
/// This recreates the behavior of a button in a `UIBarButtonItem`:
/// - Make button (including badge) transparent while tapped
/// - Touch target with of at least 44 pt (recommended by HIG). Height depends on the maximal navigation bar height.
/// - Same offset as right bar button item
///
/// Additional features:
/// - Badge value updates when `openBallotsCount` is updated
///
/// Changing the appearance of the button and badge while tapping requires to create a container that reacts to the user interaction.
/// We chose a UIButton subclass because it's supposed to be a button. This requires us to imitate the appearance of a `.system`
/// `UIButton`, because we cannot subclass such a button. We imitate the appearance of a system button by applying a custom
/// symbol configuration to the button's `imageView` and adding a custom alpha animation when highlighted (tweak by observing
/// the behavior of default `UIBarButtonItems`). These might deviate from OS behavior in the future.
///
/// If we have a navigation bar with custom right bar button items and the most right item uses a custom view the inset is twice of the
/// default. This seems to be an issue since many years (at least iOS 6). This view applies a workaround when the array from
/// `asRightBarButtonItems()` is used as `rightBarButtonItems` on the view controller's `navigationItem`. The
/// workaround uses the fact that a standard `UIBarButtonItem` as most right item reduces the inset and a fixed spacer of 8 always
/// leads to a space of 8 (what we want). By defining the same inset in `alignmentRectInsets` and setting
/// `intrinsicContentSize` to our `ChatViewConfiguration.Profile.BallotButton.minimumTouchTargetWidth`
/// minus the alignment offset our item behaves like a standard `UIBarButtonItem`.
///
/// **Note: This might break at any time as it depends on the behavior of spacer `UIBarButtonItem`s.**
///
/// Our workaround is based on this [blogpost](https://www.matrixprojects.net/p/uibarbuttonitem-ios11/) and
/// works at least until iOS 15.6.
///
/// Alternatively a `UIView` could be used as a container for the `UIButton` and badge view. This would us allow to use the system
/// button with its default styling. Touches could be observed adding targets to the button for the needed events. However, we found no
/// way to synchronize the animation of the button with the badge view and the same workaround for `UIBarButtonItem`s with custom
/// views would have to be applied.
///
/// Another alternative could be a direct subclass of `UIControl`. This was not further investigated.
///
/// # References
/// - [HIG](https://developer.apple.com/design/human-interface-guidelines/ios/visual-design/adaptivity-and-layout/)
///
class BallotWithOpenCountButton: ThemedCodeButton {
    
    // MARK: - Public interface
    
    /// Open ballot count shown in badge
    ///
    /// This can be reassigned at any time. Default value `0`.
    var openBallotsCount: UInt = 0 {
        didSet {
            badgeView.value = openBallotsCount
            updateAccessibilityLabel()
        }
    }
    
    /// Ready to use right bar button items
    ///
    /// To align the button correctly as a right bar button item in a navigation bar some tweaks are need such that the button appears
    /// like a default bar button item.
    ///
    /// Based on [this workaround](https://www.matrixprojects.net/p/uibarbuttonitem-ios11/).
    var rightBarButtonItems: [UIBarButtonItem] {
        let ballotBarButtonItem = UIBarButtonItem(customView: self)
        
        // This breaks if ...`.offsetCorrection` > 8
        let spacer = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        spacer.width = ChatViewConfiguration.Profile.BallotButton.offsetCorrection
        
        return [spacer, ballotBarButtonItem]
    }
    
    // MARK: - Private properties
    
    private lazy var badgeView: MKNumberBadgeView = {
        let badgeView = MKNumberBadgeView()
        
        badgeView.value = openBallotsCount
        badgeView.alignment = .right
        badgeView.font = ChatViewConfiguration.Profile.BallotButton.badgeFont
        badgeView.isUserInteractionEnabled = false
        
        NSLayoutConstraint.activate([
            badgeView.widthAnchor.constraint(
                greaterThanOrEqualToConstant: ChatViewConfiguration.Profile.BallotButton.minBadgeSize.width
            ),
            badgeView.heightAnchor.constraint(
                greaterThanOrEqualToConstant: ChatViewConfiguration.Profile.BallotButton.minBadgeSize.height
            ),
        ])
        
        return badgeView
    }()
    
    private lazy var highlightAnimator = UIViewPropertyAnimator.barButtonHighlightAnimator(for: self)
    
    // MARK: - Lifecycle
    
    deinit {
        highlightAnimator.stopAnimation(true)
    }
    
    // MARK: - Configuration
    
    override func configureButton() {
        super.configureButton()
        
        setImage(BundleUtil.imageNamed(ChatViewConfiguration.Profile.BallotButton.ballotSymbolName), for: .normal)
        // Try to approximate appearance of a system bar button item
        setPreferredSymbolConfiguration(
            ChatViewConfiguration.Profile.BallotButton.symbolConfiguration,
            forImageIn: .normal
        )
        adjustsImageWhenHighlighted = false
        
        addSubview(badgeView)
        badgeView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // We assume there exists an image view
            badgeView.topAnchor.constraint(
                equalTo: imageView!.topAnchor,
                constant: -(
                    badgeView.badgeSize.height * ChatViewConfiguration.Profile.BallotButton
                        .badgeOffsetFromBallotSymbolRatio
                )
            ),
            badgeView.trailingAnchor.constraint(
                equalTo: imageView!.trailingAnchor,
                constant: badgeView.badgeSize.height * ChatViewConfiguration.Profile.BallotButton
                    .badgeOffsetFromBallotSymbolRatio
            ),
        ])
        
        updateAccessibilityLabel()
    }
    
    // MARK: - Update
    
    private func updateAccessibilityLabel() {
        accessibilityLabel = String.localizedStringWithFormat(
            BundleUtil.localizedString(forKey: "ballots_with_open_count_accessibility"),
            openBallotsCount
        )
    }
    
    // MARK: - Button interaction
    
    override var isHighlighted: Bool {
        didSet {
            guard isHighlighted != oldValue else {
                return
            }
            
            highlightAnimator.pauseAnimation()
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
            width: ChatViewConfiguration.Profile.BallotButton.minimumTouchTargetWidth -
                ChatViewConfiguration.Profile.BallotButton.offsetCorrection,
            height: UIView.layoutFittingExpandedSize.height
        )
    }
    
    override var alignmentRectInsets: UIEdgeInsets {
        UIEdgeInsets(top: 0, left: 0, bottom: 0, right: ChatViewConfiguration.Profile.BallotButton.offsetCorrection)
    }
}
