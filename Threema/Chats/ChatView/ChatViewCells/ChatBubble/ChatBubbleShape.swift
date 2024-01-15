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

/// Shapes for chat bubble background
enum ChatBubbleShape {
    
    /// A rect with rounded corners filling `frame`
    /// - Parameter frame: Frame to fill with rect
    /// - Parameter traitCollection: Trait collection of environment the rounded rect will be shown in
    /// - Returns: Bezier path of rect
    static func roundedRect(for frame: CGRect, with traitCollection: UITraitCollection) -> UIBezierPath {
        if traitCollection.preferredContentSizeCategory < .large {
            return UIBezierPath(
                roundedRect: frame,
                cornerRadius: ChatViewConfiguration.ChatBubble.smallerContentSizeConfigurationCornerRadius
            )
        }
        else {
            return UIBezierPath(roundedRect: frame, cornerRadius: ChatViewConfiguration.ChatBubble.cornerRadius)
        }
    }
    
    /// Leading arrow in `frame`
    ///
    /// This should be combined with a `roundedRect(for:)` in the same frame. Note that this overlaps the frame by ~1 pt
    /// on the leading edge so it looks visually better when combined with the rounded rect.
    ///
    /// - Parameter frame: Frame to draw arrow for
    /// - Returns: Bezier path of arrow
    static func leadingArrow(for frame: CGRect) -> UIBezierPath {
        let leadingArrowPath = UIBezierPath()

        leadingArrowPath.move(to: CGPoint(x: frame.minX + 18, y: frame.maxY - 19))
        leadingArrowPath.addCurve(
            to: CGPoint(x: frame.minX - 1, y: frame.maxY),
            controlPoint1: CGPoint(x: frame.minX + 18, y: frame.maxY - 8.51),
            controlPoint2: CGPoint(x: frame.minX + 9.49, y: frame.maxY)
        )
        leadingArrowPath.addCurve(
            to: CGPoint(x: frame.minX + 1.37, y: frame.maxY - 3.16),
            controlPoint1: CGPoint(x: frame.minX - 0.06, y: frame.maxY - 0.91),
            controlPoint2: CGPoint(x: frame.minX + 0.73, y: frame.maxY - 1.97)
        )
        leadingArrowPath.addCurve(
            to: CGPoint(x: frame.minX + 3.24, y: frame.maxY - 13.06),
            controlPoint1: CGPoint(x: frame.minX + 2.59, y: frame.maxY - 5.44),
            controlPoint2: CGPoint(x: frame.minX + 3.24, y: frame.maxY - 7.89)
        )
        leadingArrowPath.addLine(to: CGPoint(x: frame.minX + 3.24, y: frame.maxY - 13.06))
        leadingArrowPath.addLine(to: CGPoint(x: frame.minX + 3.24, y: frame.maxY - 19))
        leadingArrowPath.addLine(to: CGPoint(x: frame.minX + 18, y: frame.maxY - 19))
        leadingArrowPath.close()
        leadingArrowPath.usesEvenOddFillRule = true
        
        return leadingArrowPath
    }
    
    static func bubbles(for frame: CGRect) -> [UIBezierPath] {
        typealias AttachedBubbleConfig = ChatViewConfiguration.TypingIndicator.AttachedBubble
        typealias SmallBubbleConfig = ChatViewConfiguration.TypingIndicator.SmallBubble
        
        let attachedBubbleRect = CGRect(
            x: frame.minX + AttachedBubbleConfig.xOffset,
            y: frame.maxY + AttachedBubbleConfig.yOffset,
            width: AttachedBubbleConfig.width,
            height: AttachedBubbleConfig.height
        )
        
        let smallBubbleRect = CGRect(
            x: frame.minX + SmallBubbleConfig.xOffset,
            y: frame.maxY + SmallBubbleConfig.yOffset,
            width: SmallBubbleConfig.width,
            height: SmallBubbleConfig.height
        )
        
        let attachedBubblePath = UIBezierPath(ovalIn: attachedBubbleRect)
        attachedBubblePath.fill()
        
        let smallBubblePath =
            UIBezierPath(ovalIn: smallBubbleRect)
        smallBubblePath.fill()
        
        return [smallBubblePath, attachedBubblePath]
    }
    
    /// Trailing arrow in `frame`
    ///
    /// This should be combined with a `roundedRect(for:)` in the same frame. Note that this overlaps the frame by ~1 pt
    /// on the trailing edge so it looks visually better when combined with the rounded rect.
    ///
    /// - Parameter frame: Frame to draw arrow for
    /// - Returns: Bezier path of arrow
    static func trailingArrow(for frame: CGRect) -> UIBezierPath {
        let trailingArrowPath = UIBezierPath()
        
        trailingArrowPath.move(to: CGPoint(x: frame.maxX - 18, y: frame.maxY - 19))
        trailingArrowPath.addCurve(
            to: CGPoint(x: frame.maxX + 1, y: frame.maxY),
            controlPoint1: CGPoint(x: frame.maxX - 18, y: frame.maxY - 8.51),
            controlPoint2: CGPoint(x: frame.maxX - 9.49, y: frame.maxY)
        )
        trailingArrowPath.addCurve(
            to: CGPoint(x: frame.maxX - 1.37, y: frame.maxY - 3.16),
            controlPoint1: CGPoint(x: frame.maxX + 0.06, y: frame.maxY - 0.91),
            controlPoint2: CGPoint(x: frame.maxX - 0.73, y: frame.maxY - 1.97)
        )
        trailingArrowPath.addCurve(
            to: CGPoint(x: frame.maxX - 3.24, y: frame.maxY - 13.06),
            controlPoint1: CGPoint(x: frame.maxX - 2.59, y: frame.maxY - 5.44),
            controlPoint2: CGPoint(x: frame.maxX - 3.24, y: frame.maxY - 7.88)
        )
        trailingArrowPath.addLine(to: CGPoint(x: frame.maxX - 3.24, y: frame.maxY - 13.06))
        trailingArrowPath.addLine(to: CGPoint(x: frame.maxX - 3.24, y: frame.maxY - 19))
        trailingArrowPath.addLine(to: CGPoint(x: frame.maxX - 18, y: frame.maxY - 19))
        trailingArrowPath.close()
        trailingArrowPath.usesEvenOddFillRule = true
        
        return trailingArrowPath
    }
}
