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

final class MessageSymbolMetadataVibrancyView: UIView {
    
    /// Symbol to show before the text (leading side) if any
    var symbolName: String? {
        didSet {
            messageSymbolMetadataView.symbolName = symbolName
            blurEffectViewWorkaroundMessageSymbolMetadataView.symbolName = symbolName
        }
    }
    
    /// Metadata string to show if any
    var metadataString: String? {
        didSet {
            messageSymbolMetadataView.metadataString = metadataString
            blurEffectViewWorkaroundMessageSymbolMetadataView.metadataString = metadataString
        }
    }

    /// The view that should be affected by the vibrancy configuration
    var vibrancyAffectedView: MessageSymbolMetadataView {
        messageSymbolMetadataView
    }
    
    /// The view that should not be affected by the vibrancy configuration
    var vibrancyUnaffectedView: MessageSymbolMetadataView {
        blurEffectViewWorkaroundMessageSymbolMetadataView
    }
    
    private lazy var messageSymbolMetadataView = MessageSymbolMetadataView()
    private lazy var blurEffectViewWorkaroundMessageSymbolMetadataView = MessageSymbolMetadataView()
     
    // MARK: - Updates
    
    func updateColors() {
        
        if UIAccessibility.isReduceTransparencyEnabled {
            blurEffectViewWorkaroundMessageSymbolMetadataView.overrideColor = .secondaryLabel
        }
        else if UIAccessibility.isDarkerSystemColorsEnabled {
            blurEffectViewWorkaroundMessageSymbolMetadataView.overrideColor = .label
        }
        else {
            blurEffectViewWorkaroundMessageSymbolMetadataView.overrideColor = .clear
        }
        
        messageSymbolMetadataView.updateColors()
        blurEffectViewWorkaroundMessageSymbolMetadataView.updateColors()
    }
}
