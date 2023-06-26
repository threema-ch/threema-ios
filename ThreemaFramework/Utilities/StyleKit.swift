//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2023 Threema GmbH
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
import UIKit

/// Images generated at runtime
///
/// How to add a new image:
/// 1. Create a new image in PaintCode
/// 2. Add generated code at the bottom
/// 3. Create computed class variable and add it to cache after first access
/// 4. Add variable to `debugStackView`
open class StyleKit: NSObject {
    // MARK: Cache
    
    private enum Cache {
        static var verificationSmall0: UIImage?
        static var verificationSmall1: UIImage?
        static var verificationSmall2: UIImage?
        static var verificationSmall3: UIImage?
        static var verificationSmall4: UIImage?
        
        static var verification0: UIImage?
        static var verification1: UIImage?
        static var verification2: UIImage?
        static var verification3: UIImage?
        static var verification4: UIImage?
        
        static var verificationBig0: UIImage?
        static var verificationBig1: UIImage?
        static var verificationBig2: UIImage?
        static var verificationBig3: UIImage?
        static var verificationBig4: UIImage?
        
        static var check: UIImage?
        static var uncheck: UIImage?
        
        static var workIcon: UIImage?
        static var houseIcon: UIImage?
        
        static var finger: UIImage?
                
        static var checkedBackground: UIImage?
    }
    
    // MARK: Cache functions
    
    public class func resetCache() {
        Cache.verificationSmall0 = nil
        Cache.verificationSmall1 = nil
        Cache.verificationSmall2 = nil
        Cache.verificationSmall3 = nil
        Cache.verificationSmall4 = nil
        
        Cache.verification0 = nil
        Cache.verification1 = nil
        Cache.verification2 = nil
        Cache.verification3 = nil
        Cache.verification4 = nil
        
        Cache.verificationBig0 = nil
        Cache.verificationBig1 = nil
        Cache.verificationBig2 = nil
        Cache.verificationBig3 = nil
        Cache.verificationBig4 = nil
        
        Cache.check = nil
        Cache.uncheck = nil
        
        Cache.workIcon = nil
        Cache.houseIcon = nil
        
        Cache.finger = nil
                
        Cache.checkedBackground = nil
    }
    
    /// Reset images that change depending on theme
    ///
    /// - Note: You will also have to reload the image where you used it
    @objc public class func resetThemedCache() {
        Cache.workIcon = nil
        Cache.houseIcon = nil
        Cache.checkedBackground = nil
    }
        
    // MARK: - Debugging
    
    /// Stack View containing all StyleKit images for debugging
    ///
    /// - Returns: Stack View containing all StyleKit images
    public class func debugStackView() -> UIStackView {
        let stack = UIStackView(arrangedSubviews: [
            UIImageView(image: StyleKit.verificationSmall0),
            UIImageView(image: StyleKit.verificationSmall1),
            UIImageView(image: StyleKit.verificationSmall2),
            UIImageView(image: StyleKit.verificationSmall3),
            UIImageView(image: StyleKit.verificationSmall4),
            UIImageView(image: StyleKit.verification0),
            UIImageView(image: StyleKit.verification1),
            UIImageView(image: StyleKit.verification2),
            UIImageView(image: StyleKit.verification3),
            UIImageView(image: StyleKit.verification4),
            UIImageView(image: StyleKit.verificationBig0),
            UIImageView(image: StyleKit.verificationBig1),
            UIImageView(image: StyleKit.verificationBig2),
            UIImageView(image: StyleKit.verificationBig3),
            UIImageView(image: StyleKit.verificationBig4),
            UIImageView(image: StyleKit.check),
            UIImageView(image: StyleKit.uncheck),
            UIImageView(image: StyleKit.workIcon),
            UIImageView(image: StyleKit.houseIcon),
            UIImageView(image: StyleKit.finger),
            UIImageView(image: StyleKit.checkedBackground),
            // Add new images above this comment
        ])
        
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24)
        stack.isLayoutMarginsRelativeArrangement = true
        
        return stack
    }
    
    // MARK: - Images
    
    // Note: The width and height are in points. i.e. `UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 0)` creates a context that draws the image in the scale of the current device.
    
    // MARK: Small Generated Images (32 x 8 pt)
    
    /// Image size for small verification levels
    public static let verificationSmallSize = CGSize(width: 32, height: 8)
    
    /// Verification level 0 image (32 x 8 pt)
    @objc public dynamic class var verificationSmall0: UIImage {
        if Cache.verificationSmall0 != nil {
            return Cache.verificationSmall0!
        }
        
        UIGraphicsBeginImageContextWithOptions(verificationSmallSize, false, 0)
        StyleKit.drawVerification(frame: CGRect(origin: .zero, size: verificationSmallSize), level: 0)
        
        Cache.verificationSmall0 = UIGraphicsGetImageFromCurrentImageContext()!
            .resizableImage(withCapInsets: UIEdgeInsets.zero, resizingMode: .stretch)
        UIGraphicsEndImageContext()
        
        return Cache.verificationSmall0!
    }
    
    /// Verification level 1 image (32 x 8 pt)
    @objc public dynamic class var verificationSmall1: UIImage {
        if Cache.verificationSmall1 != nil {
            return Cache.verificationSmall1!
        }
        
        UIGraphicsBeginImageContextWithOptions(verificationSmallSize, false, 0)
        StyleKit.drawVerification(frame: CGRect(origin: .zero, size: verificationSmallSize), level: 1)
        
        Cache.verificationSmall1 = UIGraphicsGetImageFromCurrentImageContext()!
            .resizableImage(withCapInsets: UIEdgeInsets.zero, resizingMode: .stretch)
        UIGraphicsEndImageContext()
        
        return Cache.verificationSmall1!
    }
    
    /// Verification level 2 image (32 x 8 pt)
    @objc public dynamic class var verificationSmall2: UIImage {
        if Cache.verificationSmall2 != nil {
            return Cache.verificationSmall2!
        }
        
        UIGraphicsBeginImageContextWithOptions(verificationSmallSize, false, 0)
        StyleKit.drawVerification(frame: CGRect(origin: .zero, size: verificationSmallSize), level: 2)
        
        Cache.verificationSmall2 = UIGraphicsGetImageFromCurrentImageContext()!
            .resizableImage(withCapInsets: UIEdgeInsets.zero, resizingMode: .stretch)
        UIGraphicsEndImageContext()
        
        return Cache.verificationSmall2!
    }
    
    /// Verification level work 1 image (32 x 8 pt)
    @objc public dynamic class var verificationSmall3: UIImage {
        if Cache.verificationSmall3 != nil {
            return Cache.verificationSmall3!
        }
        
        UIGraphicsBeginImageContextWithOptions(verificationSmallSize, false, 0)
        StyleKit.drawVerification(frame: CGRect(origin: .zero, size: verificationSmallSize), level: 3)
        
        Cache.verificationSmall3 = UIGraphicsGetImageFromCurrentImageContext()!
            .resizableImage(withCapInsets: UIEdgeInsets.zero, resizingMode: .stretch)
        UIGraphicsEndImageContext()
        
        return Cache.verificationSmall3!
    }
    
    /// Verification level work 2 image (32 x 8 pt)
    @objc public dynamic class var verificationSmall4: UIImage {
        if Cache.verificationSmall4 != nil {
            return Cache.verificationSmall4!
        }
        
        UIGraphicsBeginImageContextWithOptions(verificationSmallSize, false, 0)
        StyleKit.drawVerification(frame: CGRect(origin: .zero, size: verificationSmallSize), level: 4)
        
        Cache.verificationSmall4 = UIGraphicsGetImageFromCurrentImageContext()!
            .resizableImage(withCapInsets: UIEdgeInsets.zero, resizingMode: .stretch)
        UIGraphicsEndImageContext()
        
        return Cache.verificationSmall4!
    }
    
    // MARK: Normal Generated Images (48 x 12 pt)
    
    public static let verificationSize = CGSize(width: 48, height: 12)
    
    /// Verification level 0 image (48 x 12 pt)
    @objc public dynamic class var verification0: UIImage {
        if Cache.verification0 != nil {
            return Cache.verification0!
        }
        
        UIGraphicsBeginImageContextWithOptions(verificationSize, false, 0)
        StyleKit.drawVerification(frame: CGRect(origin: .zero, size: verificationSize), level: 0)
        
        Cache.verification0 = UIGraphicsGetImageFromCurrentImageContext()!
            .resizableImage(withCapInsets: UIEdgeInsets.zero, resizingMode: .stretch)
        UIGraphicsEndImageContext()
        
        return Cache.verification0!
    }
    
    /// Verification level 1 image (48 x 12 pt)
    @objc public dynamic class var verification1: UIImage {
        if Cache.verification1 != nil {
            return Cache.verification1!
        }
        
        UIGraphicsBeginImageContextWithOptions(verificationSize, false, 0)
        StyleKit.drawVerification(frame: CGRect(origin: .zero, size: verificationSize), level: 1)
        
        Cache.verification1 = UIGraphicsGetImageFromCurrentImageContext()!
            .resizableImage(withCapInsets: UIEdgeInsets.zero, resizingMode: .stretch)
        UIGraphicsEndImageContext()
        
        return Cache.verification1!
    }
    
    /// Verification level 2 image (48 x 12 pt)
    @objc public dynamic class var verification2: UIImage {
        if Cache.verification2 != nil {
            return Cache.verification2!
        }
        
        UIGraphicsBeginImageContextWithOptions(verificationSize, false, 0)
        StyleKit.drawVerification(frame: CGRect(origin: .zero, size: verificationSize), level: 2)
        
        Cache.verification2 = UIGraphicsGetImageFromCurrentImageContext()!
            .resizableImage(withCapInsets: UIEdgeInsets.zero, resizingMode: .stretch)
        UIGraphicsEndImageContext()
        
        return Cache.verification2!
    }
    
    /// Verification level work 1 image (48 x 12 pt)
    @objc public dynamic class var verification3: UIImage {
        if Cache.verification3 != nil {
            return Cache.verification3!
        }
        
        UIGraphicsBeginImageContextWithOptions(verificationSize, false, 0)
        StyleKit.drawVerification(frame: CGRect(origin: .zero, size: verificationSize), level: 3)
        
        Cache.verification3 = UIGraphicsGetImageFromCurrentImageContext()!
            .resizableImage(withCapInsets: UIEdgeInsets.zero, resizingMode: .stretch)
        UIGraphicsEndImageContext()
        
        return Cache.verification3!
    }
    
    /// Verification level work 2 image (48 x 12 pt)
    @objc public dynamic class var verification4: UIImage {
        if Cache.verification4 != nil {
            return Cache.verification4!
        }
        
        UIGraphicsBeginImageContextWithOptions(verificationSize, false, 0)
        StyleKit.drawVerification(frame: CGRect(origin: .zero, size: verificationSize), level: 4)
        
        Cache.verification4 = UIGraphicsGetImageFromCurrentImageContext()!
            .resizableImage(withCapInsets: UIEdgeInsets.zero, resizingMode: .stretch)
        UIGraphicsEndImageContext()
        
        return Cache.verification4!
    }
        
    // MARK: Big Generated Images (163 x 41 pt)
    
    public static let verificationBigSize = CGSize(width: 163, height: 41)
    
    /// Verification level 0 image (163 x 41 pt)
    @objc public dynamic class var verificationBig0: UIImage {
        if Cache.verificationBig0 != nil {
            return Cache.verificationBig0!
        }
        
        UIGraphicsBeginImageContextWithOptions(verificationBigSize, false, 0)
        StyleKit.drawVerification(frame: CGRect(origin: .zero, size: verificationBigSize), level: 0)
        
        Cache.verificationBig0 = UIGraphicsGetImageFromCurrentImageContext()!
            .resizableImage(withCapInsets: UIEdgeInsets.zero, resizingMode: .stretch)
        UIGraphicsEndImageContext()
        
        return Cache.verificationBig0!
    }
    
    /// Verification level 1 image (163 x 41 pt)
    @objc public dynamic class var verificationBig1: UIImage {
        if Cache.verificationBig1 != nil {
            return Cache.verificationBig1!
        }
        
        UIGraphicsBeginImageContextWithOptions(verificationBigSize, false, 0)
        StyleKit.drawVerification(frame: CGRect(origin: .zero, size: verificationBigSize), level: 1)
        
        Cache.verificationBig1 = UIGraphicsGetImageFromCurrentImageContext()!
            .resizableImage(withCapInsets: UIEdgeInsets.zero, resizingMode: .stretch)
        UIGraphicsEndImageContext()
        
        return Cache.verificationBig1!
    }
    
    /// Verification level 2 image (163 x 41 pt)
    @objc public dynamic class var verificationBig2: UIImage {
        if Cache.verificationBig2 != nil {
            return Cache.verificationBig2!
        }
        
        UIGraphicsBeginImageContextWithOptions(verificationBigSize, false, 0)
        StyleKit.drawVerification(frame: CGRect(origin: .zero, size: verificationBigSize), level: 2)
        
        Cache.verificationBig2 = UIGraphicsGetImageFromCurrentImageContext()!
            .resizableImage(withCapInsets: UIEdgeInsets.zero, resizingMode: .stretch)
        UIGraphicsEndImageContext()
        
        return Cache.verificationBig2!
    }
    
    /// Verification level work 1 image (163 x 41 pt)
    @objc public dynamic class var verificationBig3: UIImage {
        if Cache.verificationBig3 != nil {
            return Cache.verificationBig3!
        }
        
        UIGraphicsBeginImageContextWithOptions(verificationBigSize, false, 0)
        StyleKit.drawVerification(frame: CGRect(origin: .zero, size: verificationBigSize), level: 3)
        
        Cache.verificationBig3 = UIGraphicsGetImageFromCurrentImageContext()!
            .resizableImage(withCapInsets: UIEdgeInsets.zero, resizingMode: .stretch)
        UIGraphicsEndImageContext()
        
        return Cache.verificationBig3!
    }
    
    /// Verification level work 2 image (163 x 41 pt)
    @objc public dynamic class var verificationBig4: UIImage {
        if Cache.verificationBig4 != nil {
            return Cache.verificationBig4!
        }
        
        UIGraphicsBeginImageContextWithOptions(verificationBigSize, false, 0)
        StyleKit.drawVerification(frame: CGRect(origin: .zero, size: verificationBigSize), level: 4)
        
        Cache.verificationBig4 = UIGraphicsGetImageFromCurrentImageContext()!
            .resizableImage(withCapInsets: UIEdgeInsets.zero, resizingMode: .stretch)
        UIGraphicsEndImageContext()
        
        return Cache.verificationBig4!
    }
    
    // MARK: Check (26 x 26 pt)
    
    /// Check (26 x 26 pt)
    @objc public dynamic class var check: UIImage {
        if Cache.check != nil {
            return Cache.check!
        }
        
        let width = 26
        let height = 26
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 0)
        StyleKit.drawCheck(frame: CGRect(x: 0, y: 0, width: width, height: height))
        
        Cache.check = UIGraphicsGetImageFromCurrentImageContext()!
            .resizableImage(withCapInsets: UIEdgeInsets.zero, resizingMode: .stretch)
        UIGraphicsEndImageContext()
        
        return Cache.check!
    }
    
    /// Uncheck (26 x 26 pt)
    @objc public dynamic class var uncheck: UIImage {
        if Cache.uncheck != nil {
            return Cache.uncheck!
        }
        
        let width = 26
        let height = 26
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 0)
        StyleKit.drawUncheck(frame: CGRect(x: 0, y: 0, width: width, height: height))
        
        Cache.uncheck = UIGraphicsGetImageFromCurrentImageContext()!
            .resizableImage(withCapInsets: UIEdgeInsets.zero, resizingMode: .stretch)
        UIGraphicsEndImageContext()
        
        return Cache.uncheck!
    }
    
    // MARK: Work & Home (50 x 50 pt)
    
    /// Work icon (50 x 50 pt)
    @objc public dynamic class var workIcon: UIImage {
        if Cache.workIcon != nil {
            return Cache.workIcon!
        }
        
        let width = 50
        let height = 50
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 0)
        StyleKit.drawWorkIcon(frame: CGRect(x: 0, y: 0, width: width, height: height), resizing: .aspectFit)
        
        Cache.workIcon = UIGraphicsGetImageFromCurrentImageContext()!
            .resizableImage(withCapInsets: UIEdgeInsets.zero, resizingMode: .stretch)
        UIGraphicsEndImageContext()
        
        return Cache.workIcon!
    }
    
    /// House icon (private Threema version; 50 x 50 pt)
    @objc public dynamic class var houseIcon: UIImage {
        if Cache.houseIcon != nil {
            return Cache.houseIcon!
        }
        
        let width = 50
        let height = 50
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 0)
        StyleKit.drawHouseIcon(frame: CGRect(x: 0, y: 0, width: width, height: height), resizing: .aspectFit)
        
        Cache.houseIcon = UIGraphicsGetImageFromCurrentImageContext()!
            .resizableImage(withCapInsets: UIEdgeInsets.zero, resizingMode: .stretch)
        UIGraphicsEndImageContext()
        
        return Cache.houseIcon!
    }
    
    // MARK: Finger
    
    /// Finger (220 x 250 pt)
    @objc public dynamic class var finger: UIImage {
        if Cache.finger != nil {
            return Cache.finger!
        }
        
        let width = 220
        let height = 250
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 0)
        StyleKit.drawFinger(frame: CGRect(x: 0, y: 0, width: width, height: height), resizing: .aspectFit)
        
        Cache.finger = UIGraphicsGetImageFromCurrentImageContext()!
            .resizableImage(withCapInsets: UIEdgeInsets.zero, resizingMode: .stretch)
        UIGraphicsEndImageContext()
        
        return Cache.finger!
    }
    
    // MARK: Selection image for image picker
    
    /// Selection image for image picker (100 x 100 pt)
    @objc public dynamic class var checkedBackground: UIImage {
        if let cachedIcon = Cache.checkedBackground {
            return cachedIcon
        }
        
        let dimensions = 100
        UIGraphicsBeginImageContextWithOptions(CGSize(width: dimensions, height: dimensions), false, 0)
        StyleKit.drawCheckedBackground(frame: CGRect(x: 0, y: 0, width: dimensions, height: dimensions))
        
        Cache.checkedBackground = UIGraphicsGetImageFromCurrentImageContext()!
            .resizableImage(withCapInsets: .zero, resizingMode: .stretch)
        UIGraphicsEndImageContext()

        return Cache.checkedBackground!
    }
    
    // MARK: - Drawing Methods
    
    public dynamic class func drawVerification(frame: CGRect = CGRect(x: 0, y: 0, width: 32, height: 8), level: Int) {
        //// General Declarations
        // This non-generic function dramatically improves compilation times of complex expressions.
        func fastFloor(_ x: CGFloat) -> CGFloat { floor(x) }
        
        //// Subframes
        let group = CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height)
        var width = fastFloor(group.width * 0.25000 + 0.5) - fastFloor(group.width * 0.00000 + 0.5)
        var height = fastFloor(group.height * 1.00000 + 0.5) - fastFloor(group.height * 0.00000 + 0.5)
        
        if height > width {
            height = width
        }
        else {
            width = height
        }
        
        let red: UIColor = Colors.red
        let orange: UIColor = Colors.orange
        let green: UIColor = Colors.green
        let gray: UIColor = Colors.gray
        let blue: UIColor = Colors.blue
        //// Group
        //// Oval Drawing
        let ovalPath = UIBezierPath(ovalIn: CGRect(
            x: group.minX + fastFloor(group.width * 0.00000 + 0.5),
            y: group.minY + fastFloor(group.height * 0.00000 + 0.5),
            width: width,
            height: height
        ))
        switch level {
        case 0:
            red.setFill()
        case 1:
            orange.setFill()
        case 2:
            green.setFill()
        case 3, 4:
            blue.setFill()
        default:
            gray.setFill()
        }
        ovalPath.fill()
        
        //// Oval 2 Drawing
        let oval2Path = UIBezierPath(ovalIn: CGRect(
            x: group.minX + fastFloor(group.width * 0.37500 + 0.5),
            y: group.minY + fastFloor(group.height * 0.00000 + 0.5),
            width: width,
            height: height
        ))
        switch level {
        case 1:
            orange.setFill()
        case 2:
            green.setFill()
        case 3, 4:
            blue.setFill()
        default:
            gray.setFill()
        }
        oval2Path.fill()
        
        //// Oval 3 Drawing
        let oval3Path = UIBezierPath(ovalIn: CGRect(
            x: group.minX + fastFloor(group.width * 0.75000 + 0.5),
            y: group.minY + fastFloor(group.height * 0.00000 + 0.5),
            width: width,
            height: height
        ))
        switch level {
        case 2:
            green.setFill()
        case 4:
            blue.setFill()
        default:
            gray.setFill()
        }
        oval3Path.fill()
    }
    
    @objc public dynamic class func drawCheck(frame: CGRect = CGRect(x: 0, y: 0, width: 22, height: 22)) {
        //// General Declarations
        // This non-generic function dramatically improves compilation times of complex expressions.
        func fastFloor(_ x: CGFloat) -> CGFloat { floor(x) }
        
        //// Color Declarations
        let color2 = Colors.gray as UIColor
        let color3 = UIColor.white
        let color4 = .primary as UIColor
        
        //// Subframes
        let group = CGRect(x: frame.minX + 1, y: frame.minY + 1, width: frame.width - 2, height: frame.height - 2)
        
        //// Group
        //// Oval 2 Drawing
        let oval2Path = UIBezierPath(ovalIn: CGRect(
            x: group.minX + fastFloor(group.width * 0.05000 + 0.5),
            y: group.minY + fastFloor(group.height * 0.05000 + 0.5),
            width: fastFloor(group.width * 0.95000 + 0.5) - fastFloor(group.width * 0.05000 + 0.5),
            height: fastFloor(group.height * 0.95000 + 0.5) - fastFloor(group.height * 0.05000 + 0.5)
        ))
        color4.setFill()
        oval2Path.fill()
        oval2Path.lineWidth = 1
        
        //// Oval Drawing
        let ovalPath = UIBezierPath(ovalIn: CGRect(
            x: group.minX + fastFloor(group.width * 0.00000 + 0.5),
            y: group.minY + fastFloor(group.height * 0.00000 + 0.5),
            width: fastFloor(group.width * 1.00000 + 0.5) - fastFloor(group.width * 0.00000 + 0.5),
            height: fastFloor(group.height * 1.00000 + 0.5) - fastFloor(group.height * 0.00000 + 0.5)
        ))
        color2.setStroke()
        ovalPath.lineWidth = 1
        ovalPath.stroke()
        
        //// Bezier Drawing
        let bezierPath = UIBezierPath()
        bezierPath.move(to: CGPoint(x: frame.minX + 0.26607 * frame.width, y: frame.minY + 0.46120 * frame.height))
        bezierPath.addCurve(
            to: CGPoint(x: frame.minX + 0.44789 * frame.width, y: frame.minY + 0.64302 * frame.height),
            controlPoint1: CGPoint(x: frame.minX + 0.44789 * frame.width, y: frame.minY + 0.64302 * frame.height),
            controlPoint2: CGPoint(x: frame.minX + 0.44789 * frame.width, y: frame.minY + 0.64302 * frame.height)
        )
        bezierPath.addLine(to: CGPoint(x: frame.minX + 0.41575 * frame.width, y: frame.minY + 0.64302 * frame.height))
        bezierPath.addLine(to: CGPoint(x: frame.minX + 0.73393 * frame.width, y: frame.minY + 0.32484 * frame.height))
        bezierPath.addCurve(
            to: CGPoint(x: frame.minX + 0.76607 * frame.width, y: frame.minY + 0.32484 * frame.height),
            controlPoint1: CGPoint(x: frame.minX + 0.74280 * frame.width, y: frame.minY + 0.31596 * frame.height),
            controlPoint2: CGPoint(x: frame.minX + 0.75720 * frame.width, y: frame.minY + 0.31596 * frame.height)
        )
        bezierPath.addCurve(
            to: CGPoint(x: frame.minX + 0.76607 * frame.width, y: frame.minY + 0.35698 * frame.height),
            controlPoint1: CGPoint(x: frame.minX + 0.77495 * frame.width, y: frame.minY + 0.33371 * frame.height),
            controlPoint2: CGPoint(x: frame.minX + 0.77495 * frame.width, y: frame.minY + 0.34810 * frame.height)
        )
        bezierPath.addLine(to: CGPoint(x: frame.minX + 0.44789 * frame.width, y: frame.minY + 0.67516 * frame.height))
        bezierPath.addCurve(
            to: CGPoint(x: frame.minX + 0.41575 * frame.width, y: frame.minY + 0.67516 * frame.height),
            controlPoint1: CGPoint(x: frame.minX + 0.43901 * frame.width, y: frame.minY + 0.68404 * frame.height),
            controlPoint2: CGPoint(x: frame.minX + 0.42462 * frame.width, y: frame.minY + 0.68404 * frame.height)
        )
        bezierPath.addCurve(
            to: CGPoint(x: frame.minX + 0.23393 * frame.width, y: frame.minY + 0.49334 * frame.height),
            controlPoint1: CGPoint(x: frame.minX + 0.41575 * frame.width, y: frame.minY + 0.67516 * frame.height),
            controlPoint2: CGPoint(x: frame.minX + 0.41575 * frame.width, y: frame.minY + 0.67516 * frame.height)
        )
        bezierPath.addCurve(
            to: CGPoint(x: frame.minX + 0.23393 * frame.width, y: frame.minY + 0.46120 * frame.height),
            controlPoint1: CGPoint(x: frame.minX + 0.22505 * frame.width, y: frame.minY + 0.48447 * frame.height),
            controlPoint2: CGPoint(x: frame.minX + 0.22505 * frame.width, y: frame.minY + 0.47008 * frame.height)
        )
        bezierPath.addCurve(
            to: CGPoint(x: frame.minX + 0.26607 * frame.width, y: frame.minY + 0.46120 * frame.height),
            controlPoint1: CGPoint(x: frame.minX + 0.24280 * frame.width, y: frame.minY + 0.45233 * frame.height),
            controlPoint2: CGPoint(x: frame.minX + 0.25720 * frame.width, y: frame.minY + 0.45233 * frame.height)
        )
        bezierPath.close()
        color3.setFill()
        bezierPath.fill()
    }

    @objc public dynamic class func drawUncheck(frame: CGRect = CGRect(x: 0, y: 0, width: 22, height: 22)) {
        //// Color Declarations
        let color = Colors.gray as UIColor
        
        //// Oval Drawing
        let ovalPath =
            UIBezierPath(ovalIn: CGRect(
                x: frame.minX + 1,
                y: frame.minY + 1,
                width: frame.width - 2,
                height: frame.height - 2
            ))
        color.setStroke()
        ovalPath.lineWidth = 1
        ovalPath.stroke()
    }
    
    @objc public dynamic class func drawWorkIcon(
        frame targetFrame: CGRect = CGRect(x: 0, y: 0, width: 20, height: 20),
        resizing: ResizingBehavior = .aspectFit
    ) {
        //// General Declarations
        let context = UIGraphicsGetCurrentContext()!
        
        //// Resize to Target Frame
        context.saveGState()
        let resizedFrame: CGRect = resizing.apply(rect: CGRect(x: 0, y: 0, width: 20, height: 20), target: targetFrame)
        context.translateBy(x: resizedFrame.minX, y: resizedFrame.minY)
        context.scaleBy(x: resizedFrame.width / 20, y: resizedFrame.height / 20)
        
        //// Color Declarations
        let fillColor = UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 1.000)
        let fillColor2 = Colors.blue
        
        //// work_app_icon_mit_rand Group
        //// Path Drawing
        let pathPath = UIBezierPath()
        pathPath.move(to: CGPoint(x: 10, y: 0))
        pathPath.addLine(to: CGPoint(x: 10, y: 0))
        pathPath.addCurve(
            to: CGPoint(x: 20, y: 10),
            controlPoint1: CGPoint(x: 15.52, y: 0),
            controlPoint2: CGPoint(x: 20, y: 4.48)
        )
        pathPath.addCurve(
            to: CGPoint(x: 10, y: 20),
            controlPoint1: CGPoint(x: 20, y: 15.52),
            controlPoint2: CGPoint(x: 15.52, y: 20)
        )
        pathPath.addCurve(
            to: CGPoint(x: 0, y: 10),
            controlPoint1: CGPoint(x: 4.48, y: 20),
            controlPoint2: CGPoint(x: 0, y: 15.52)
        )
        pathPath.addLine(to: CGPoint(x: 0, y: 10))
        pathPath.addCurve(
            to: CGPoint(x: 10, y: 0),
            controlPoint1: CGPoint(x: 0, y: 4.48),
            controlPoint2: CGPoint(x: 4.48, y: 0)
        )
        pathPath.close()
        pathPath.move(to: CGPoint(x: 10, y: 0.91))
        pathPath.addLine(to: CGPoint(x: 10, y: 0.91))
        pathPath.addCurve(
            to: CGPoint(x: 0.91, y: 10),
            controlPoint1: CGPoint(x: 4.98, y: 0.91),
            controlPoint2: CGPoint(x: 0.91, y: 4.98)
        )
        pathPath.addCurve(
            to: CGPoint(x: 10, y: 19.09),
            controlPoint1: CGPoint(x: 0.91, y: 15.02),
            controlPoint2: CGPoint(x: 4.98, y: 19.09)
        )
        pathPath.addCurve(
            to: CGPoint(x: 19.09, y: 10),
            controlPoint1: CGPoint(x: 15.02, y: 19.09),
            controlPoint2: CGPoint(x: 19.09, y: 15.02)
        )
        pathPath.addLine(to: CGPoint(x: 19.09, y: 10))
        pathPath.addCurve(
            to: CGPoint(x: 10, y: 0.91),
            controlPoint1: CGPoint(x: 19.09, y: 4.98),
            controlPoint2: CGPoint(x: 15.02, y: 0.91)
        )
        pathPath.close()
        fillColor.setFill()
        pathPath.fill()
        
        //// Shape 2 Drawing
        let shape2Path = UIBezierPath()
        shape2Path.move(to: CGPoint(x: 10, y: 0.91))
        shape2Path.addLine(to: CGPoint(x: 10, y: 19.09))
        shape2Path.addLine(to: CGPoint(x: 10, y: 0.91))
        shape2Path.close()
        shape2Path.move(to: CGPoint(x: 11.36, y: 5.45))
        shape2Path.addLine(to: CGPoint(x: 8.64, y: 5.45))
        shape2Path.addLine(to: CGPoint(x: 8.64, y: 5.45))
        shape2Path.addCurve(
            to: CGPoint(x: 7.73, y: 6.36),
            controlPoint1: CGPoint(x: 8.13, y: 5.45),
            controlPoint2: CGPoint(x: 7.73, y: 5.86)
        )
        shape2Path.addLine(to: CGPoint(x: 7.73, y: 7.27))
        shape2Path.addLine(to: CGPoint(x: 6.36, y: 7.27))
        shape2Path.addLine(to: CGPoint(x: 6.36, y: 7.27))
        shape2Path.addCurve(
            to: CGPoint(x: 5.45, y: 8.18),
            controlPoint1: CGPoint(x: 5.86, y: 7.27),
            controlPoint2: CGPoint(x: 5.45, y: 7.68)
        )
        shape2Path.addLine(to: CGPoint(x: 5.45, y: 12.73))
        shape2Path.addLine(to: CGPoint(x: 5.45, y: 12.73))
        shape2Path.addCurve(
            to: CGPoint(x: 6.36, y: 13.64),
            controlPoint1: CGPoint(x: 5.45, y: 13.23),
            controlPoint2: CGPoint(x: 5.86, y: 13.64)
        )
        shape2Path.addLine(to: CGPoint(x: 13.64, y: 13.64))
        shape2Path.addLine(to: CGPoint(x: 13.64, y: 13.64))
        shape2Path.addCurve(
            to: CGPoint(x: 14.55, y: 12.73),
            controlPoint1: CGPoint(x: 14.14, y: 13.64),
            controlPoint2: CGPoint(x: 14.55, y: 13.23)
        )
        shape2Path.addLine(to: CGPoint(x: 14.55, y: 8.18))
        shape2Path.addLine(to: CGPoint(x: 14.55, y: 8.18))
        shape2Path.addCurve(
            to: CGPoint(x: 13.64, y: 7.27),
            controlPoint1: CGPoint(x: 14.55, y: 7.68),
            controlPoint2: CGPoint(x: 14.14, y: 7.27)
        )
        shape2Path.addLine(to: CGPoint(x: 12.27, y: 7.27))
        shape2Path.addLine(to: CGPoint(x: 12.27, y: 6.36))
        shape2Path.addLine(to: CGPoint(x: 12.27, y: 6.36))
        shape2Path.addCurve(
            to: CGPoint(x: 11.36, y: 5.45),
            controlPoint1: CGPoint(x: 12.27, y: 5.86),
            controlPoint2: CGPoint(x: 11.87, y: 5.45)
        )
        shape2Path.close()
        shape2Path.move(to: CGPoint(x: 11.36, y: 6.36))
        shape2Path.addLine(to: CGPoint(x: 11.36, y: 7.27))
        shape2Path.addLine(to: CGPoint(x: 8.64, y: 7.27))
        shape2Path.addLine(to: CGPoint(x: 8.64, y: 6.36))
        shape2Path.addLine(to: CGPoint(x: 11.36, y: 6.36))
        shape2Path.close()
        shape2Path.usesEvenOddFillRule = true
        fillColor.setFill()
        shape2Path.fill()
        
        //// Shape Drawing
        let shapePath = UIBezierPath()
        shapePath.move(to: CGPoint(x: 10, y: 0.91))
        shapePath.addLine(to: CGPoint(x: 10, y: 0.91))
        shapePath.addCurve(
            to: CGPoint(x: 19.09, y: 10),
            controlPoint1: CGPoint(x: 15.02, y: 0.91),
            controlPoint2: CGPoint(x: 19.09, y: 4.98)
        )
        shapePath.addCurve(
            to: CGPoint(x: 10, y: 19.09),
            controlPoint1: CGPoint(x: 19.09, y: 15.02),
            controlPoint2: CGPoint(x: 15.02, y: 19.09)
        )
        shapePath.addCurve(
            to: CGPoint(x: 0.91, y: 10),
            controlPoint1: CGPoint(x: 4.98, y: 19.09),
            controlPoint2: CGPoint(x: 0.91, y: 15.02)
        )
        shapePath.addLine(to: CGPoint(x: 0.91, y: 10))
        shapePath.addCurve(
            to: CGPoint(x: 10, y: 0.91),
            controlPoint1: CGPoint(x: 0.91, y: 4.98),
            controlPoint2: CGPoint(x: 4.98, y: 0.91)
        )
        shapePath.close()
        shapePath.move(to: CGPoint(x: 11.36, y: 5.45))
        shapePath.addLine(to: CGPoint(x: 8.64, y: 5.45))
        shapePath.addLine(to: CGPoint(x: 8.64, y: 5.45))
        shapePath.addCurve(
            to: CGPoint(x: 7.73, y: 6.36),
            controlPoint1: CGPoint(x: 8.13, y: 5.45),
            controlPoint2: CGPoint(x: 7.73, y: 5.86)
        )
        shapePath.addLine(to: CGPoint(x: 7.73, y: 7.27))
        shapePath.addLine(to: CGPoint(x: 6.36, y: 7.27))
        shapePath.addLine(to: CGPoint(x: 6.36, y: 7.27))
        shapePath.addCurve(
            to: CGPoint(x: 5.45, y: 8.18),
            controlPoint1: CGPoint(x: 5.86, y: 7.27),
            controlPoint2: CGPoint(x: 5.45, y: 7.68)
        )
        shapePath.addLine(to: CGPoint(x: 5.45, y: 12.73))
        shapePath.addLine(to: CGPoint(x: 5.45, y: 12.73))
        shapePath.addCurve(
            to: CGPoint(x: 6.36, y: 13.64),
            controlPoint1: CGPoint(x: 5.45, y: 13.23),
            controlPoint2: CGPoint(x: 5.86, y: 13.64)
        )
        shapePath.addLine(to: CGPoint(x: 13.64, y: 13.64))
        shapePath.addLine(to: CGPoint(x: 13.64, y: 13.64))
        shapePath.addCurve(
            to: CGPoint(x: 14.55, y: 12.73),
            controlPoint1: CGPoint(x: 14.14, y: 13.64),
            controlPoint2: CGPoint(x: 14.55, y: 13.23)
        )
        shapePath.addLine(to: CGPoint(x: 14.55, y: 8.18))
        shapePath.addLine(to: CGPoint(x: 14.55, y: 8.18))
        shapePath.addCurve(
            to: CGPoint(x: 13.64, y: 7.27),
            controlPoint1: CGPoint(x: 14.55, y: 7.68),
            controlPoint2: CGPoint(x: 14.14, y: 7.27)
        )
        shapePath.addLine(to: CGPoint(x: 12.27, y: 7.27))
        shapePath.addLine(to: CGPoint(x: 12.27, y: 6.36))
        shapePath.addLine(to: CGPoint(x: 12.27, y: 6.36))
        shapePath.addCurve(
            to: CGPoint(x: 11.36, y: 5.45),
            controlPoint1: CGPoint(x: 12.27, y: 5.86),
            controlPoint2: CGPoint(x: 11.87, y: 5.45)
        )
        shapePath.close()
        shapePath.move(to: CGPoint(x: 11.36, y: 6.36))
        shapePath.addLine(to: CGPoint(x: 11.36, y: 7.27))
        shapePath.addLine(to: CGPoint(x: 8.64, y: 7.27))
        shapePath.addLine(to: CGPoint(x: 8.64, y: 6.36))
        shapePath.addLine(to: CGPoint(x: 11.36, y: 6.36))
        shapePath.close()
        shapePath.usesEvenOddFillRule = true
        fillColor2.setFill()
        shapePath.fill()
        
        context.restoreGState()
    }

    @objc public dynamic class func drawHouseIcon(
        frame targetFrame: CGRect = CGRect(x: 0, y: 0, width: 20, height: 20),
        resizing: ResizingBehavior = .aspectFit
    ) {
        //// General Declarations
        let context = UIGraphicsGetCurrentContext()!
        
        //// Resize to Target Frame
        context.saveGState()
        let resizedFrame: CGRect = resizing.apply(rect: CGRect(x: 0, y: 0, width: 20, height: 20), target: targetFrame)
        context.translateBy(x: resizedFrame.minX, y: resizedFrame.minY)
        context.scaleBy(x: resizedFrame.width / 20, y: resizedFrame.height / 20)
        
        //// Color Declarations
        let fillColor = UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 1.000)
        let fillColor2 = Colors.green as UIColor
        
        //// consumer_app_icon_mit_rand Group
        //// Path Drawing
        let pathPath = UIBezierPath()
        pathPath.move(to: CGPoint(x: 10, y: 0))
        pathPath.addLine(to: CGPoint(x: 10, y: 0))
        pathPath.addCurve(
            to: CGPoint(x: 20, y: 10),
            controlPoint1: CGPoint(x: 15.52, y: 0),
            controlPoint2: CGPoint(x: 20, y: 4.48)
        )
        pathPath.addCurve(
            to: CGPoint(x: 10, y: 20),
            controlPoint1: CGPoint(x: 20, y: 15.52),
            controlPoint2: CGPoint(x: 15.52, y: 20)
        )
        pathPath.addCurve(
            to: CGPoint(x: 0, y: 10),
            controlPoint1: CGPoint(x: 4.48, y: 20),
            controlPoint2: CGPoint(x: 0, y: 15.52)
        )
        pathPath.addLine(to: CGPoint(x: 0, y: 10))
        pathPath.addCurve(
            to: CGPoint(x: 10, y: 0),
            controlPoint1: CGPoint(x: 0, y: 4.48),
            controlPoint2: CGPoint(x: 4.48, y: 0)
        )
        pathPath.close()
        pathPath.move(to: CGPoint(x: 10, y: 0.91))
        pathPath.addLine(to: CGPoint(x: 10, y: 0.91))
        pathPath.addCurve(
            to: CGPoint(x: 0.91, y: 10),
            controlPoint1: CGPoint(x: 4.98, y: 0.91),
            controlPoint2: CGPoint(x: 0.91, y: 4.98)
        )
        pathPath.addCurve(
            to: CGPoint(x: 10, y: 19.09),
            controlPoint1: CGPoint(x: 0.91, y: 15.02),
            controlPoint2: CGPoint(x: 4.98, y: 19.09)
        )
        pathPath.addCurve(
            to: CGPoint(x: 19.09, y: 10),
            controlPoint1: CGPoint(x: 15.02, y: 19.09),
            controlPoint2: CGPoint(x: 19.09, y: 15.02)
        )
        pathPath.addLine(to: CGPoint(x: 19.09, y: 10))
        pathPath.addCurve(
            to: CGPoint(x: 10, y: 0.91),
            controlPoint1: CGPoint(x: 19.09, y: 4.98),
            controlPoint2: CGPoint(x: 15.02, y: 0.91)
        )
        pathPath.close()
        fillColor.setFill()
        pathPath.fill()
        
        //// Shape Drawing
        let shapePath = UIBezierPath()
        shapePath.move(to: CGPoint(x: 10, y: 0.91))
        shapePath.addLine(to: CGPoint(x: 10, y: 0.91))
        shapePath.addCurve(
            to: CGPoint(x: 19.09, y: 10),
            controlPoint1: CGPoint(x: 15.02, y: 0.91),
            controlPoint2: CGPoint(x: 19.09, y: 4.98)
        )
        shapePath.addCurve(
            to: CGPoint(x: 10, y: 19.09),
            controlPoint1: CGPoint(x: 19.09, y: 15.02),
            controlPoint2: CGPoint(x: 15.02, y: 19.09)
        )
        shapePath.addCurve(
            to: CGPoint(x: 0.91, y: 10),
            controlPoint1: CGPoint(x: 4.98, y: 19.09),
            controlPoint2: CGPoint(x: 0.91, y: 15.02)
        )
        shapePath.addLine(to: CGPoint(x: 0.91, y: 10))
        shapePath.addCurve(
            to: CGPoint(x: 10, y: 0.91),
            controlPoint1: CGPoint(x: 0.91, y: 4.98),
            controlPoint2: CGPoint(x: 4.98, y: 0.91)
        )
        shapePath.close()
        shapePath.move(to: CGPoint(x: 10, y: 7.27))
        shapePath.addLine(to: CGPoint(x: 6.36, y: 10.91))
        shapePath.addLine(to: CGPoint(x: 6.36, y: 14.09))
        shapePath.addLine(to: CGPoint(x: 6.36, y: 14.09))
        shapePath.addCurve(
            to: CGPoint(x: 6.82, y: 14.55),
            controlPoint1: CGPoint(x: 6.36, y: 14.34),
            controlPoint2: CGPoint(x: 6.57, y: 14.55)
        )
        shapePath.addLine(to: CGPoint(x: 13.18, y: 14.55))
        shapePath.addLine(to: CGPoint(x: 13.18, y: 14.55))
        shapePath.addCurve(
            to: CGPoint(x: 13.64, y: 14.09),
            controlPoint1: CGPoint(x: 13.43, y: 14.55),
            controlPoint2: CGPoint(x: 13.64, y: 14.34)
        )
        shapePath.addLine(to: CGPoint(x: 13.64, y: 10.91))
        shapePath.addLine(to: CGPoint(x: 10, y: 7.27))
        shapePath.close()
        shapePath.move(to: CGPoint(x: 10.32, y: 5.02))
        shapePath.addLine(to: CGPoint(x: 10.32, y: 5.02))
        shapePath.addCurve(
            to: CGPoint(x: 9.68, y: 5.02),
            controlPoint1: CGPoint(x: 10.14, y: 4.84),
            controlPoint2: CGPoint(x: 9.86, y: 4.84)
        )
        shapePath.addLine(to: CGPoint(x: 4.86, y: 9.84))
        shapePath.addLine(to: CGPoint(x: 5.5, y: 10.48))
        shapePath.addLine(to: CGPoint(x: 10, y: 5.99))
        shapePath.addLine(to: CGPoint(x: 14.5, y: 10.49))
        shapePath.addLine(to: CGPoint(x: 15.14, y: 9.84))
        shapePath.addLine(to: CGPoint(x: 10.32, y: 5.02))
        shapePath.close()
        shapePath.usesEvenOddFillRule = true
        fillColor2.setFill()
        shapePath.fill()
        
        //// Shape 2 Drawing
        let shape2Path = UIBezierPath()
        shape2Path.move(to: CGPoint(x: 0.91, y: 10))
        shape2Path.addLine(to: CGPoint(x: 0.91, y: 10))
        shape2Path.addCurve(
            to: CGPoint(x: 0.91, y: 10),
            controlPoint1: CGPoint(x: 0.91, y: 4.98),
            controlPoint2: CGPoint(x: 0.91, y: 10)
        )
        shape2Path.close()
        shape2Path.move(to: CGPoint(x: 10, y: 7.27))
        shape2Path.addLine(to: CGPoint(x: 6.36, y: 10.91))
        shape2Path.addLine(to: CGPoint(x: 6.36, y: 14.09))
        shape2Path.addLine(to: CGPoint(x: 6.36, y: 14.09))
        shape2Path.addCurve(
            to: CGPoint(x: 6.82, y: 14.55),
            controlPoint1: CGPoint(x: 6.36, y: 14.34),
            controlPoint2: CGPoint(x: 6.57, y: 14.55)
        )
        shape2Path.addLine(to: CGPoint(x: 13.18, y: 14.55))
        shape2Path.addLine(to: CGPoint(x: 13.18, y: 14.55))
        shape2Path.addCurve(
            to: CGPoint(x: 13.64, y: 14.09),
            controlPoint1: CGPoint(x: 13.43, y: 14.55),
            controlPoint2: CGPoint(x: 13.64, y: 14.34)
        )
        shape2Path.addLine(to: CGPoint(x: 13.64, y: 10.91))
        shape2Path.addLine(to: CGPoint(x: 10, y: 7.27))
        shape2Path.close()
        shape2Path.move(to: CGPoint(x: 10.32, y: 5.02))
        shape2Path.addLine(to: CGPoint(x: 10.32, y: 5.02))
        shape2Path.addCurve(
            to: CGPoint(x: 9.68, y: 5.02),
            controlPoint1: CGPoint(x: 10.14, y: 4.84),
            controlPoint2: CGPoint(x: 9.86, y: 4.84)
        )
        shape2Path.addLine(to: CGPoint(x: 4.86, y: 9.84))
        shape2Path.addLine(to: CGPoint(x: 5.5, y: 10.48))
        shape2Path.addLine(to: CGPoint(x: 10, y: 5.99))
        shape2Path.addLine(to: CGPoint(x: 14.5, y: 10.49))
        shape2Path.addLine(to: CGPoint(x: 15.14, y: 9.84))
        shape2Path.addLine(to: CGPoint(x: 10.32, y: 5.02))
        shape2Path.close()
        shape2Path.usesEvenOddFillRule = true
        fillColor.setFill()
        shape2Path.fill()
        
        context.restoreGState()
    }
    
    @objc public dynamic class func drawFinger(
        frame targetFrame: CGRect = CGRect(x: 0, y: 0, width: 220, height: 250),
        resizing: ResizingBehavior = .aspectFit
    ) {
        //// General Declarations
        let context = UIGraphicsGetCurrentContext()!
        
        //// Resize to Target Frame
        context.saveGState()
        let resizedFrame: CGRect = resizing.apply(
            rect: CGRect(x: 0, y: 0, width: 220, height: 250),
            target: targetFrame
        )
        context.translateBy(x: resizedFrame.minX, y: resizedFrame.minY)
        context.scaleBy(x: resizedFrame.width / 220, y: resizedFrame.height / 250)
        
        //// Color Declarations
        let fillColor = UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 1.000)
        let fillColor5 = Colors.primaryWizard as UIColor
        let fillColor6 = UIColor(red: 0.847, green: 0.847, blue: 0.847, alpha: 1.000)
        
        //// finger_with_circles Group
        //// Bezier Drawing
        let bezierPath = UIBezierPath()
        bezierPath.move(to: CGPoint(x: 109.96, y: 53.34))
        bezierPath.addLine(to: CGPoint(x: 109.98, y: 53.34))
        bezierPath.addCurve(
            to: CGPoint(x: 166.5, y: 110.05),
            controlPoint1: CGPoint(x: 141.19, y: 53.34),
            controlPoint2: CGPoint(x: 166.5, y: 78.73)
        )
        bezierPath.addCurve(
            to: CGPoint(x: 109.98, y: 166.76),
            controlPoint1: CGPoint(x: 166.5, y: 141.37),
            controlPoint2: CGPoint(x: 141.19, y: 166.76)
        )
        bezierPath.addCurve(
            to: CGPoint(x: 53.47, y: 110.05),
            controlPoint1: CGPoint(x: 78.77, y: 166.76),
            controlPoint2: CGPoint(x: 53.47, y: 141.37)
        )
        bezierPath.addCurve(
            to: CGPoint(x: 95.36, y: 55.27),
            controlPoint1: CGPoint(x: 53.47, y: 84.39),
            controlPoint2: CGPoint(x: 70.65, y: 61.92)
        )
        bezierPath.addLine(to: CGPoint(x: 95.36, y: 55.27))
        bezierPath.addCurve(
            to: CGPoint(x: 109.98, y: 53.34),
            controlPoint1: CGPoint(x: 100.13, y: 53.99),
            controlPoint2: CGPoint(x: 105.04, y: 53.34)
        )
        bezierPath.move(to: CGPoint(x: 109.96, y: 46.68))
        bezierPath.addLine(to: CGPoint(x: 109.96, y: 46.68))
        bezierPath.addLine(to: CGPoint(x: 109.91, y: 46.68))
        bezierPath.addCurve(
            to: CGPoint(x: 46.8, y: 110.01),
            controlPoint1: CGPoint(x: 75.06, y: 46.68),
            controlPoint2: CGPoint(x: 46.8, y: 75.03)
        )
        bezierPath.addCurve(
            to: CGPoint(x: 109.91, y: 173.35),
            controlPoint1: CGPoint(x: 46.8, y: 145),
            controlPoint2: CGPoint(x: 75.06, y: 173.35)
        )
        bezierPath.addCurve(
            to: CGPoint(x: 173.03, y: 110.01),
            controlPoint1: CGPoint(x: 144.77, y: 173.35),
            controlPoint2: CGPoint(x: 173.03, y: 145)
        )
        bezierPath.addCurve(
            to: CGPoint(x: 170.88, y: 93.62),
            controlPoint1: CGPoint(x: 173.03, y: 104.48),
            controlPoint2: CGPoint(x: 172.31, y: 98.97)
        )
        bezierPath.addLine(to: CGPoint(x: 170.91, y: 93.73))
        bezierPath.addCurve(
            to: CGPoint(x: 109.8, y: 46.68),
            controlPoint1: CGPoint(x: 163.5, y: 65.98),
            controlPoint2: CGPoint(x: 138.44, y: 46.68)
        )
        bezierPath.addLine(to: CGPoint(x: 109.96, y: 46.68))
        bezierPath.close()
        fillColor5.setFill()
        bezierPath.fill()
        
        //// Bezier 2 Drawing
        context.saveGState()
        context.setAlpha(0.4)
        
        let bezier2Path = UIBezierPath()
        bezier2Path.move(to: CGPoint(x: 109.98, y: 30))
        bezier2Path.addLine(to: CGPoint(x: 110.01, y: 30))
        bezier2Path.addCurve(
            to: CGPoint(x: 189.79, y: 110.07),
            controlPoint1: CGPoint(x: 154.07, y: 30),
            controlPoint2: CGPoint(x: 189.79, y: 65.85)
        )
        bezier2Path.addCurve(
            to: CGPoint(x: 110.01, y: 190.13),
            controlPoint1: CGPoint(x: 189.79, y: 154.28),
            controlPoint2: CGPoint(x: 154.07, y: 190.13)
        )
        bezier2Path.addCurve(
            to: CGPoint(x: 30.23, y: 110.07),
            controlPoint1: CGPoint(x: 65.95, y: 190.13),
            controlPoint2: CGPoint(x: 30.23, y: 154.28)
        )
        bezier2Path.addCurve(
            to: CGPoint(x: 89.36, y: 32.73),
            controlPoint1: CGPoint(x: 30.23, y: 73.83),
            controlPoint2: CGPoint(x: 54.48, y: 42.11)
        )
        bezier2Path.addLine(to: CGPoint(x: 89.37, y: 32.73))
        bezier2Path.addCurve(
            to: CGPoint(x: 110.01, y: 30),
            controlPoint1: CGPoint(x: 96.1, y: 30.92),
            controlPoint2: CGPoint(x: 103.04, y: 30)
        )
        bezier2Path.move(to: CGPoint(x: 109.98, y: 23.34))
        bezier2Path.addLine(to: CGPoint(x: 109.98, y: 30))
        bezier2Path.addLine(to: CGPoint(x: 109.98, y: 23.34))
        bezier2Path.addLine(to: CGPoint(x: 109.91, y: 23.34))
        bezier2Path.addCurve(
            to: CGPoint(x: 23.53, y: 110.02),
            controlPoint1: CGPoint(x: 62.2, y: 23.34),
            controlPoint2: CGPoint(x: 23.53, y: 62.15)
        )
        bezier2Path.addCurve(
            to: CGPoint(x: 109.91, y: 196.7),
            controlPoint1: CGPoint(x: 23.53, y: 157.89),
            controlPoint2: CGPoint(x: 62.2, y: 196.7)
        )
        bezier2Path.addCurve(
            to: CGPoint(x: 196.29, y: 110.02),
            controlPoint1: CGPoint(x: 157.61, y: 196.7),
            controlPoint2: CGPoint(x: 196.29, y: 157.89)
        )
        bezier2Path.addCurve(
            to: CGPoint(x: 193.34, y: 87.58),
            controlPoint1: CGPoint(x: 196.29, y: 102.44),
            controlPoint2: CGPoint(x: 195.3, y: 94.9)
        )
        bezier2Path.addLine(to: CGPoint(x: 193.39, y: 87.75))
        bezier2Path.addCurve(
            to: CGPoint(x: 109.73, y: 23.34),
            controlPoint1: CGPoint(x: 183.24, y: 49.76),
            controlPoint2: CGPoint(x: 148.93, y: 23.34)
        )
        bezier2Path.addLine(to: CGPoint(x: 109.98, y: 23.34))
        bezier2Path.close()
        fillColor5.setFill()
        bezier2Path.fill()
        
        context.restoreGState()
        
        //// Bezier 3 Drawing
        context.saveGState()
        context.setAlpha(0.1)
        
        let bezier3Path = UIBezierPath()
        bezier3Path.move(to: CGPoint(x: 109.99, y: 6.67))
        bezier3Path.addLine(to: CGPoint(x: 110.03, y: 6.67))
        bezier3Path.addCurve(
            to: CGPoint(x: 213.09, y: 110.08),
            controlPoint1: CGPoint(x: 166.95, y: 6.67),
            controlPoint2: CGPoint(x: 213.09, y: 52.97)
        )
        bezier3Path.addCurve(
            to: CGPoint(x: 110.03, y: 213.5),
            controlPoint1: CGPoint(x: 213.09, y: 167.2),
            controlPoint2: CGPoint(x: 166.95, y: 213.5)
        )
        bezier3Path.addCurve(
            to: CGPoint(x: 6.98, y: 110.08),
            controlPoint1: CGPoint(x: 53.12, y: 213.5),
            controlPoint2: CGPoint(x: 6.98, y: 167.2)
        )
        bezier3Path.addCurve(
            to: CGPoint(x: 83.36, y: 10.19),
            controlPoint1: CGPoint(x: 6.98, y: 63.28),
            controlPoint2: CGPoint(x: 38.31, y: 22.3)
        )
        bezier3Path.addLine(to: CGPoint(x: 83.37, y: 10.19))
        bezier3Path.addCurve(
            to: CGPoint(x: 110.03, y: 6.67),
            controlPoint1: CGPoint(x: 92.06, y: 7.85),
            controlPoint2: CGPoint(x: 101.03, y: 6.67)
        )
        bezier3Path.move(to: CGPoint(x: 110, y: -0))
        bezier3Path.addLine(to: CGPoint(x: 110, y: 6.67))
        bezier3Path.addLine(to: CGPoint(x: 110, y: -0))
        bezier3Path.addLine(to: CGPoint(x: 109.83, y: -0))
        bezier3Path.addCurve(
            to: CGPoint(x: 0, y: 110.21),
            controlPoint1: CGPoint(x: 49.17, y: -0),
            controlPoint2: CGPoint(x: 0, y: 49.34)
        )
        bezier3Path.addCurve(
            to: CGPoint(x: 109.83, y: 220.43),
            controlPoint1: CGPoint(x: 0, y: 171.08),
            controlPoint2: CGPoint(x: 49.17, y: 220.43)
        )
        bezier3Path.addCurve(
            to: CGPoint(x: 219.66, y: 110.21),
            controlPoint1: CGPoint(x: 170.49, y: 220.43),
            controlPoint2: CGPoint(x: 219.66, y: 171.08)
        )
        bezier3Path.addCurve(
            to: CGPoint(x: 175.93, y: 22.19),
            controlPoint1: CGPoint(x: 219.66, y: 75.61),
            controlPoint2: CGPoint(x: 203.46, y: 43.02)
        )
        bezier3Path.addLine(to: CGPoint(x: 175.96, y: 22.22))
        bezier3Path.addCurve(
            to: CGPoint(x: 109.78, y: -0),
            controlPoint1: CGPoint(x: 156.89, y: 7.8),
            controlPoint2: CGPoint(x: 133.66, y: -0)
        )
        bezier3Path.addLine(to: CGPoint(x: 110, y: -0))
        bezier3Path.close()
        fillColor5.setFill()
        bezier3Path.fill()
        
        context.restoreGState()
        
        //// Bezier 4 Drawing
        let bezier4Path = UIBezierPath()
        bezier4Path.move(to: CGPoint(x: 101.24, y: 249.96))
        bezier4Path.addLine(to: CGPoint(x: 193.35, y: 249.96))
        bezier4Path.addLine(to: CGPoint(x: 152.9, y: 98.47))
        bezier4Path.addLine(to: CGPoint(x: 152.91, y: 98.52))
        bezier4Path.addCurve(
            to: CGPoint(x: 98.43, y: 66.95),
            controlPoint1: CGPoint(x: 146.55, y: 74.7),
            controlPoint2: CGPoint(x: 122.16, y: 60.57)
        )
        bezier4Path.addCurve(
            to: CGPoint(x: 66.97, y: 121.63),
            controlPoint1: CGPoint(x: 74.69, y: 73.33),
            controlPoint2: CGPoint(x: 60.61, y: 97.81)
        )
        bezier4Path.addLine(to: CGPoint(x: 101.24, y: 249.96))
        bezier4Path.close()
        fillColor.setFill()
        bezier4Path.fill()
        
        //// Bezier 5 Drawing
        let bezier5Path = UIBezierPath()
        bezier5Path.move(to: CGPoint(x: 100.77, y: 75.71))
        bezier5Path.addLine(to: CGPoint(x: 100.76, y: 75.71))
        bezier5Path.addCurve(
            to: CGPoint(x: 75.07, y: 103.85),
            controlPoint1: CGPoint(x: 87.48, y: 79.29),
            controlPoint2: CGPoint(x: 77.46, y: 90.26)
        )
        bezier5Path.addLine(to: CGPoint(x: 84.33, y: 138.17))
        bezier5Path.addLine(to: CGPoint(x: 84.33, y: 138.17))
        bezier5Path.addCurve(
            to: CGPoint(x: 123.5, y: 160.87),
            controlPoint1: CGPoint(x: 88.9, y: 155.29),
            controlPoint2: CGPoint(x: 106.44, y: 165.46)
        )
        bezier5Path.addCurve(
            to: CGPoint(x: 146.12, y: 121.56),
            controlPoint1: CGPoint(x: 140.57, y: 156.28),
            controlPoint2: CGPoint(x: 150.69, y: 138.68)
        )
        bezier5Path.addLine(to: CGPoint(x: 136.9, y: 87.02))
        bezier5Path.addLine(to: CGPoint(x: 137.04, y: 87.19))
        bezier5Path.addCurve(
            to: CGPoint(x: 100.77, y: 75.71),
            controlPoint1: CGPoint(x: 128.2, y: 76.62),
            controlPoint2: CGPoint(x: 114.06, y: 72.14)
        )
        bezier5Path.addLine(to: CGPoint(x: 100.77, y: 75.71))
        bezier5Path.close()
        fillColor6.setFill()
        bezier5Path.fill()
        
        context.restoreGState()
    }

    /// Draw image for image selection background
    ///
    /// - Parameter frame: Frame of the image
    @objc public dynamic class func drawCheckedBackground(frame: CGRect = CGRect(x: 0, y: 0, width: 62, height: 62)) {
        //// Color Declarations
        let color: UIColor = .primary

        //// Bezier Drawing
        let bezierPath = UIBezierPath()
        bezierPath.move(to: CGPoint(x: frame.minX + 0.66129 * frame.width, y: frame.minY + 4))
        bezierPath.addLine(to: CGPoint(x: frame.minX + 8.59, y: frame.minY + 4))
        bezierPath.addCurve(
            to: CGPoint(x: frame.minX + 5.89, y: frame.minY + 4.22),
            controlPoint1: CGPoint(x: frame.minX + 7.27, y: frame.minY + 4),
            controlPoint2: CGPoint(x: frame.minX + 6.61, y: frame.minY + 4)
        )
        bezierPath.addCurve(
            to: CGPoint(x: frame.minX + 4.22, y: frame.minY + 5.89),
            controlPoint1: CGPoint(x: frame.minX + 5.12, y: frame.minY + 4.51),
            controlPoint2: CGPoint(x: frame.minX + 4.51, y: frame.minY + 5.12)
        )
        bezierPath.addLine(to: CGPoint(x: frame.minX + 4.2, y: frame.minY + 6.01))
        bezierPath.addCurve(
            to: CGPoint(x: frame.minX + 4, y: frame.minY + 8.59),
            controlPoint1: CGPoint(x: frame.minX + 4, y: frame.minY + 6.61),
            controlPoint2: CGPoint(x: frame.minX + 4, y: frame.minY + 7.27)
        )
        bezierPath.addLine(to: CGPoint(x: frame.minX + 4, y: frame.maxY - 8.59))
        bezierPath.addCurve(
            to: CGPoint(x: frame.minX + 4.22, y: frame.maxY - 5.89),
            controlPoint1: CGPoint(x: frame.minX + 4, y: frame.maxY - 7.27),
            controlPoint2: CGPoint(x: frame.minX + 4, y: frame.maxY - 6.61)
        )
        bezierPath.addCurve(
            to: CGPoint(x: frame.minX + 5.89, y: frame.maxY - 4.22),
            controlPoint1: CGPoint(x: frame.minX + 4.51, y: frame.maxY - 5.12),
            controlPoint2: CGPoint(x: frame.minX + 5.12, y: frame.maxY - 4.51)
        )
        bezierPath.addLine(to: CGPoint(x: frame.minX + 6.01, y: frame.maxY - 4.2))
        bezierPath.addCurve(
            to: CGPoint(x: frame.minX + 8.59, y: frame.maxY - 4),
            controlPoint1: CGPoint(x: frame.minX + 6.61, y: frame.maxY - 4),
            controlPoint2: CGPoint(x: frame.minX + 7.27, y: frame.maxY - 4)
        )
        bezierPath.addLine(to: CGPoint(x: frame.maxX - 8.59, y: frame.maxY - 4))
        bezierPath.addCurve(
            to: CGPoint(x: frame.maxX - 5.89, y: frame.maxY - 4.22),
            controlPoint1: CGPoint(x: frame.maxX - 7.27, y: frame.maxY - 4),
            controlPoint2: CGPoint(x: frame.maxX - 6.61, y: frame.maxY - 4)
        )
        bezierPath.addCurve(
            to: CGPoint(x: frame.maxX - 4.22, y: frame.maxY - 5.89),
            controlPoint1: CGPoint(x: frame.maxX - 5.12, y: frame.maxY - 4.51),
            controlPoint2: CGPoint(x: frame.maxX - 4.51, y: frame.maxY - 5.12)
        )
        bezierPath.addLine(to: CGPoint(x: frame.maxX - 4.2, y: frame.maxY - 6.01))
        bezierPath.addCurve(
            to: CGPoint(x: frame.maxX - 4, y: frame.maxY - 8.59),
            controlPoint1: CGPoint(x: frame.maxX - 4, y: frame.maxY - 6.61),
            controlPoint2: CGPoint(x: frame.maxX - 4, y: frame.maxY - 7.27)
        )
        bezierPath.addLine(to: CGPoint(x: frame.maxX - 4, y: frame.minY + 0.33871 * frame.height))
        bezierPath.addLine(to: CGPoint(x: frame.minX + 0.69355 * frame.width, y: frame.minY + 0.33871 * frame.height))
        bezierPath.addCurve(
            to: CGPoint(x: frame.minX + 0.66129 * frame.width, y: frame.minY + 0.30645 * frame.height),
            controlPoint1: CGPoint(x: frame.minX + 0.69355 * frame.width, y: frame.minY + 0.33871 * frame.height),
            controlPoint2: CGPoint(x: frame.minX + 0.66129 * frame.width, y: frame.minY + 0.33871 * frame.height)
        )
        bezierPath.addCurve(
            to: CGPoint(x: frame.minX + 0.66129 * frame.width, y: frame.minY + 4),
            controlPoint1: CGPoint(x: frame.minX + 0.66129 * frame.width, y: frame.minY + 0.27419 * frame.height),
            controlPoint2: CGPoint(x: frame.minX + 0.66129 * frame.width, y: frame.minY + 4)
        )
        bezierPath.close()
        bezierPath.move(to: CGPoint(x: frame.maxX, y: frame.minY + 0))
        bezierPath.addCurve(
            to: CGPoint(x: frame.maxX, y: frame.maxY),
            controlPoint1: CGPoint(x: frame.maxX, y: frame.minY),
            controlPoint2: CGPoint(x: frame.maxX, y: frame.maxY)
        )
        bezierPath.addLine(to: CGPoint(x: frame.minX, y: frame.maxY))
        bezierPath.addLine(to: CGPoint(x: frame.minX, y: frame.minY))
        bezierPath.addLine(to: CGPoint(x: frame.maxX, y: frame.minY))
        bezierPath.addLine(to: CGPoint(x: frame.maxX, y: frame.minY + 0))
        bezierPath.close()
        color.setFill()
        bezierPath.fill()
    }
    
    @objc(StyleKitNameResizingBehavior)
    public enum ResizingBehavior: Int {
        case aspectFit /// The content is proportionally resized to fit into the target rectangle.
        case aspectFill /// The content is proportionally resized to completely fill the target rectangle.
        case stretch /// The content is stretched to match the entire target rectangle.
        case center /// The content is centered in the target rectangle, but it is NOT resized.
        
        public func apply(rect: CGRect, target: CGRect) -> CGRect {
            if rect == target || target == CGRect.zero {
                return rect
            }
            
            var scales = CGSize.zero
            scales.width = abs(target.width / rect.width)
            scales.height = abs(target.height / rect.height)
            
            switch self {
            case .aspectFit:
                scales.width = min(scales.width, scales.height)
                scales.height = scales.width
            case .aspectFill:
                scales.width = max(scales.width, scales.height)
                scales.height = scales.width
            case .stretch:
                break
            case .center:
                scales.width = 1
                scales.height = 1
            }
            
            var result = rect.standardized
            result.size.width *= scales.width
            result.size.height *= scales.height
            result.origin.x = target.minX + (target.width - result.width) / 2
            result.origin.y = target.minY + (target.height - result.height) / 2
            return result
        }
    }
}
