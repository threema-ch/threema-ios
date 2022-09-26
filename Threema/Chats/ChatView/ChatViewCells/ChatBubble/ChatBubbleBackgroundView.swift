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

/// View that draws a chat bubble in its bounds
final class ChatBubbleBackgroundView: UIView {
    
    /// Show a bubble arrow?
    enum ShowChatBubbleArrow {
        case leading
        case trailing
        case none
    }
    
    /// Which bubble arrow should be shown?
    var showChatBubbleArrow: ShowChatBubbleArrow = .leading
    
    // MARK: Bubble shape
    
    private lazy var backgroundLayer: CAShapeLayer = {
        let shapeLayer = CAShapeLayer()
        self.layer.addSublayer(shapeLayer)
        // You need to set the fillColor after you added it as a sublayer
        shapeLayer.fillColor = localBackgroundColor.cgColor
        return shapeLayer
    }()
    
    private(set) var backgroundPath = UIBezierPath() {
        didSet {
            backgroundLayer.path = backgroundPath.cgPath
        }
    }
        
    override var bounds: CGRect {
        set {
            super.bounds = newValue

            // Updates paths to fill new dimensions
            updatePaths(for: newValue)
        }
        get { super.bounds }
    }
    
    private func updatePaths(for frame: CGRect) {
        // We always have a rounded rectangle background
        let path = ChatBubbleShape.roundedRect(for: frame)
        
        switch showChatBubbleArrow {
        case .leading:
            path.append(ChatBubbleShape.leadingArrow(for: frame))
        case .trailing:
            path.append(ChatBubbleShape.trailingArrow(for: frame).reversing())
        case .none:
            break
        }
        
        backgroundPath = path
    }
    
    // MARK: - Color
    
    private var localBackgroundColor = Colors.chatBubbleReceived
    
    // We override the default background color implementation to not set the actual background but the colors
    // of our custom layers.
    override var backgroundColor: UIColor? {
        set {
            guard let newValue = newValue else {
                return
            }
            
            // Did the color change?
            guard newValue != localBackgroundColor else {
                return
            }
            
            // Persist the current color
            localBackgroundColor = newValue
            updateColors()
            
            // Note: We don't set the super background color
        }
        
        get {
            localBackgroundColor
        }
    }
    
    private func updateColors() {
        backgroundLayer.fillColor = localBackgroundColor.cgColor
    }
}
