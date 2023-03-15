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

import CocoaLumberjackSwift
import UIKit

extension QuickActionsView {
    /// Configuration for a quick actions view
    struct Configuration {
        let buttonSpacing: CGFloat = 8
    }
}

/// Show a set of quick actions
///
/// Show up to 4 quick action buttons. The arrangement is adapted dynamically based on the title length and dynamic font.
///
/// To change the actions shown change the `quickActions` property.
class QuickActionsView: UIStackView {
    
    // MARK: - Public property
    
    /// Current quick actions shown
    ///
    /// Changing this array is an expensive operation (all buttons are recreated).
    ///
    /// - Note: Only up to 4 actions are supported
    var quickActions = [QuickAction]() {
        didSet {
            replaceQuickActions(with: quickActions)
        }
    }
    
    // MARK: - Private properties
    
    private var buttonShadow: Bool
    private var quickActionButtons = [QuickActionButton]()
    
    private let firstStackContainer = UIStackView()
    private let secondStackContainer = UIStackView()
    
    // Optimization values for layout calculation
    private var lastViewWidth: CGFloat = 0
    private var lastDesiredMinimalFittingWidth: CGFloat = 0
    
    private let configuration = Configuration()
    
    // MARK: - Initialization
    
    /// Create quick action view with a set of quick actions
    /// - Parameters:
    ///   - quickActions: Quick actions to show
    ///   - shadow: Should each quick action button have a shadow?
    init(quickActions: [QuickAction]? = nil, shadow: Bool = true) {
        self.buttonShadow = shadow
        
        super.init(frame: .zero)
        
        configureView()
        
        if let quickActions = quickActions {
            self.quickActions = quickActions
            replaceQuickActions(with: quickActions)
        }
    }
    
    required init(coder: NSCoder) {
        self.buttonShadow = true
        
        super.init(coder: coder)
        
        configureView()
    }
    
    private func configureView() {
        [firstStackContainer, secondStackContainer].forEach { stackView in
            stackView.axis = .horizontal
            stackView.distribution = .fillEqually
            stackView.spacing = configuration.buttonSpacing
            
            addArrangedSubview(stackView)
        }
        secondStackContainer.isHidden = true

        axis = .vertical
        distribution = .equalSpacing
        spacing = configuration.buttonSpacing
    }
    
    // MARK: - Update quick actions
    
    /// Reload all quick actions
    func reload() {
        quickActionButtons.forEach { $0.reload() }
    }
    
    private func replaceQuickActions(with newQuickActions: [QuickAction]) {
        precondition(quickActions.count <= 4, "We only support up to 4 quick actions!")
        
        // Remove current buttons
        quickActionButtons.forEach { $0.removeFromSuperview() }
        quickActionButtons.removeAll()
        
        // Add new buttons
        quickActionButtons = newQuickActions.map {
            QuickActionButton(
                imageNameProvider: $0.imageNameProvider,
                title: $0.title,
                accessibilityIdentifier: $0.accessibilityIdentifier,
                action: $0.action,
                shadow: buttonShadow
            )
        }
        
        // Reset optimization variables
        lastViewWidth = 0
        lastDesiredMinimalFittingWidth = 0
    }
    
    // MARK: - Update layout
    
    // This gets called whenever our layout or content changed (e.g. device rotation, font size change, ...)
    override func layoutSubviews() {
        updateArrangement()

        super.layoutSubviews()
    }
    
    // This function gets called on every `layoutSubviews()` call. Thus it is optimized to only do work if needed.
    // Some of this code is based on the "Autosizing Views for Localization in iOS" example code from Apple.
    private func updateArrangement() {

        // Without a super view we cannot calculate the view width available
        guard let parent = superview else {
            DDLogInfo("No superview available")
            return
        }

        // Optimization:
        // We store the previous available view width and desired minimal fitting width. If both didn't
        // change the layout arrangement doesn't need to be recalculated
        let availableViewWidth = parent.bounds.inset(by: parent.layoutMargins).width
        let currentDesiredMinimalFittingWidth = desiredMaxMinimalFittingWidth()
        guard availableViewWidth != lastViewWidth ||
            currentDesiredMinimalFittingWidth != lastDesiredMinimalFittingWidth else {
            DDLogVerbose("Available view width and desired minimal fitting width didn't change.")
            return
        }
        lastViewWidth = availableViewWidth

        // This resets our arrangement to a known state
        resetViewLayout()
        
        lastDesiredMinimalFittingWidth = desiredMaxMinimalFittingWidth()
        guard quickActionButtons.count > 1,
              lastDesiredMinimalFittingWidth > availableViewWidth else {
            DDLogVerbose("There is enough space for our preferred layout!")
            return
        }
        
        // We only reach this point if we cannot fit all buttons on one horizontal line
        // (and there is more than one button)
        
        rearrangeButtons(for: availableViewWidth)
    }
    
    /// Reset layout
    ///
    /// We assume everything fits on one horizontal line.
    private func resetViewLayout() {
        // Reset stack views
        firstStackContainer.axis = .horizontal
        secondStackContainer.axis = .horizontal
        secondStackContainer.isHidden = true
        
        quickActionButtons.forEach { firstStackContainer.addArrangedSubview($0) }
    }
    
    private func rearrangeButtons(for availableViewWidth: CGFloat) {
        // How many buttons do we have?
        switch quickActionButtons.count {
        case 2:
            // If both buttons don't fit on one line arrange them vertically
            firstStackContainer.axis = .vertical
            
        case 3:
            // If three buttons don't fit on one line we but the last one below it
            
            // We know there are 3 elements in here so last will contain a value
            secondStackContainer.addArrangedSubview(quickActionButtons.last!)
            secondStackContainer.isHidden = false
            
            lastDesiredMinimalFittingWidth = desiredMaxMinimalFittingWidth()
            if lastDesiredMinimalFittingWidth > availableViewWidth {
                // If the first two buttons still don't fit on one line we arrange all buttons
                // vertically
                firstStackContainer.axis = .vertical
            }
            
        case 4:
            // If four buttons don't fit on one line we try to split them into pairs on two lines
            
            // Move last two buttons on second line
            quickActionButtons[2...].forEach { secondStackContainer.addArrangedSubview($0) }
            secondStackContainer.isHidden = false
            
            lastDesiredMinimalFittingWidth = desiredMaxMinimalFittingWidth()
            if lastDesiredMinimalFittingWidth > availableViewWidth {
                // If one pair still doesn't fit on a line together we arrange all of them
                // vertically
                firstStackContainer.axis = .vertical
                secondStackContainer.axis = .vertical
            }
            
        default:
            assertionFailure("We only support up to 4 quick actions")
        }
    }
    
    private func desiredMaxMinimalFittingWidth() -> CGFloat {
        let desiredFirstStackContainerWidth = firstStackContainer
            .systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).width
        let desiredSecondStackContainerWidth = secondStackContainer
            .systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).width
        
        return max(desiredFirstStackContainerWidth, desiredSecondStackContainerWidth)
    }
}
