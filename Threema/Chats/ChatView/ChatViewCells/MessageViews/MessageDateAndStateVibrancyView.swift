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

final class MessageDateAndStateVibrancyView {
    /// Message to show date and state for
    ///
    /// Reset to update with current message information.
    var message: BaseMessage? {
        didSet {
            guard let message else {
                return
            }
                    
            dateAndStateView.message = message
            blurEffectViewWorkaroundDateAndStateView.message = message
        }
    }
    
    /// The view that should be affected by the vibrancy configuration
    var vibrancyAffectedView: MessageDateAndStateView {
        dateAndStateView
    }
    
    /// The view that should not be affected by the vibrancy configuration
    var vibrancyUnaffectedView: MessageDateAndStateView {
        blurEffectViewWorkaroundDateAndStateView
    }
    
    private lazy var dateAndStateView = MessageDateAndStateView()
    private lazy var blurEffectViewWorkaroundDateAndStateView = MessageDateAndStateView()
     
    // MARK: - Updates
    
    func updateColors() {
        
        if UIAccessibility.isReduceTransparencyEnabled {
            blurEffectViewWorkaroundDateAndStateView.overrideColor = .secondaryLabel
        }
        else if UIAccessibility.isDarkerSystemColorsEnabled {
            blurEffectViewWorkaroundDateAndStateView.overrideColor = .label
        }
        else {
            blurEffectViewWorkaroundDateAndStateView.overrideColor = .clear
        }
    }
}
