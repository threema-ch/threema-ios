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

import CocoaLumberjackSwift
import UIKit

/// View that draws a chat bubble in its bounds
final class ChatBubbleBackgroundView: UIView {
    
    /// Show a bubble arrow?
    enum ShowChatBubbleArrow {
        case leading
        case trailing
        case bubbles
        case none
    }
    
    /// Which bubble arrow should be shown?
    var showChatBubbleArrow: ShowChatBubbleArrow = .leading {
        didSet {
            guard oldValue != showChatBubbleArrow else {
                return
            }
            
            updatePaths(for: bounds)
        }
    }
    
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
            guard animate else {
                backgroundLayer.path = backgroundPath.cgPath
                return
            }
                
            CATransaction.begin()
                
            let morph = CABasicAnimation(keyPath: "path")
                
            // If we are already animating, which will happen for example when adding the date and state view (where we
            // first get taller and then wider) we already have an animation in progress when starting the next one.
            // This gets the current position of our bubble and starts the next animation from it
            if let presentationLayer = backgroundLayer.presentation(),
               let currentPresentationLayerValue = presentationLayer.path {
                DDLogVerbose(
                    "Starting from existing animation with bounding box \(currentPresentationLayerValue.boundingBox)"
                )
                morph.fromValue = currentPresentationLayerValue
            }
            else {
                DDLogVerbose("Starting from current value \(String(describing: backgroundLayer.path?.boundingBox))")
                morph.fromValue = backgroundLayer.path
            }
                
            morph.toValue = backgroundPath.cgPath
                
            morph.duration = ChatViewConfiguration.ChatBubble.bubbleSizeChangeAnimationDurationInSeconds
            morph.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
                
            // Set value that the path should have after the animation
            // Use this instead of `.fillMode`and `isRemovedOnCompletion` because those will keep the animation
            // "running"
            backgroundLayer.path = backgroundPath.cgPath
                
            backgroundLayer.add(morph, forKey: nil)
                
            // Commit our animation
            CATransaction.commit()
        }
    }
    
    /// Used to update the bubble frame for animations
    var bubbleFrame: CGRect? {
        didSet {
            guard let bubbleFrame else {
                return
            }
            
            updatePaths(for: bubbleFrame)
        }
    }
    
    // Indicates whether the next change to `bubbleFrame` should be animated or not
    var animate = false
    
    private func updatePaths(for frame: CGRect) {
        // This could probably be optimized by caching the previous frame and only update if it changes or
        // the update is forced (when the value of `showChatBubbleArrow` changes).
        
        // We always have a rounded rectangle background
        let path = ChatBubbleShape.roundedRect(for: frame, with: traitCollection)
        
        switch showChatBubbleArrow {
        case .leading:
            path.append(ChatBubbleShape.leadingArrow(for: frame))
        case .bubbles:
            for newPath in ChatBubbleShape.bubbles(for: frame) {
                path.append(newPath)
            }
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
            guard let newValue else {
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
