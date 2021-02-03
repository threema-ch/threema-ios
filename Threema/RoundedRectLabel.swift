//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2021 Threema GmbH
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
import CocoaLumberjackSwift

@objc public class RoundedRectLabel : UILabel {
    @objc public var cornerRadius : CGFloat = 6
    private var bgc : UIColor?
    @objc public override var backgroundColor: UIColor? {
        get {
            return self.bgc
        }
        set {
            self.bgc = newValue
            super.backgroundColor = .clear
        }
    }
    
    public override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            DDLogError("Could not get current graphics context. Draw regular label")
            super.backgroundColor = self.bgc
            super.draw(rect)
            return
        }
        
        guard let text = text else {
            DDLogError("Text was nil. Can not draw label without text.")
            super.backgroundColor = self.bgc
            super.draw(rect)
            return
        }
        
        guard let font = font else {
            DDLogError("Font was nil. Can not draw label without font.")
            super.backgroundColor = self.bgc
            super.draw(rect)
            return
        }

        var textRect : CGRect = .null
        let frameSize = CGSize(width: floor(frame.size.width - cornerRadius * 0.75 * 2 + 1), height: floor(frame.size.height + 1))
        let textSize = text.boundingRect(with: frameSize, options: .usesLineFragmentOrigin, attributes: [
            NSAttributedString.Key.font: font
        ], context: nil).size

        if textAlignment == .center {
            textRect = CGRect(x: (frame.size.width - textSize.width) / 2, y: (frame.size.height - textSize.height) / 2, width: textSize.width, height: textSize.height)
            textRect = textRect.insetBy(dx: -(cornerRadius * 0.75), dy: 0)
        } else if textAlignment == .left {
            textRect = CGRect(x: 0, y: (frame.size.height - textSize.height) / 2, width: textSize.width, height: textSize.height)
            textRect = textRect.insetBy(dx: -(cornerRadius * 0.75), dy: 0)
            textRect = textRect.offsetBy(dx: cornerRadius * 0.75, dy: 0)
        } else if textAlignment == .right {
            textRect = CGRect(x: frame.size.width - textSize.width, y: (frame.size.height - textSize.height) / 2, width: textSize.width, height: textSize.height)
            textRect = textRect.insetBy(dx: -(cornerRadius * 0.75), dy: 0)
            textRect = textRect.offsetBy(dx: -(cornerRadius * 0.75), dy: 0)
        }

        let roundedRect = draw(roundedRect: textRect, context: context)
        super.draw(roundedRect)
    }
    
    public override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
        let rect = super.textRect(forBounds: bounds, limitedToNumberOfLines: numberOfLines)

        return rect.insetBy(dx: -(cornerRadius * 0.75), dy: 0)
    }

    public override func drawText(in rect: CGRect) {
        super.drawText(in: bounds.insetBy(dx: cornerRadius * 0.75, dy: 0))
    }
    
    func draw(roundedRect : CGRect, context : CGContext) -> CGRect {
        let xa = roundedRect.origin.x
        let xb = roundedRect.origin.x + cornerRadius
        let xc = roundedRect.origin.x + roundedRect.size.width - cornerRadius
        let xd = roundedRect.origin.x + roundedRect.size.width

        let ya = roundedRect.origin.y
        let yb = roundedRect.origin.y + cornerRadius
        let yc = roundedRect.origin.y + roundedRect.size.height - cornerRadius
        let yd = roundedRect.origin.y + roundedRect.size.height

        let a = CGPoint(x: CGFloat(xa), y: CGFloat(yb))
        let b = CGPoint(x: xa, y: ya)
        let b1 = CGPoint(x: xb, y: ya)
        let d = CGPoint(x: xc, y: ya)
        let e = CGPoint(x: xd, y: ya)
        let f = CGPoint(x: xd, y: yb)
        let g = CGPoint(x: xd, y: yc)
        let h = CGPoint(x: xd, y: yd)
        let i = CGPoint(x: xc, y: yd)
        let j = CGPoint(x: xb, y: yd)
        let k = CGPoint(x: xa, y: yd)
        let l = CGPoint(x: xa, y: yc)
        let m = CGPoint(x: xa, y: yb)

        context.beginPath()
        context.move(to: a)
        
        context.addArc(tangent1End: b, tangent2End: b1, radius: cornerRadius)
        context.addLine(to: d)

        context.addArc(tangent1End: e, tangent2End: f, radius: cornerRadius)
        context.addLine(to: g)

        context.addArc(tangent1End: h, tangent2End: i, radius: cornerRadius)
        context.addLine(to: j)

        context.addArc(tangent1End: k, tangent2End: l, radius: cornerRadius)
        context.addLine(to: m)

        context.closePath()
        
        guard let fillColor = self.bgc?.cgColor else {
            DDLogError("Could not get current background color. Draw regular label")
            return roundedRect
        }
        
        context.setFillColor(fillColor)
        context.fillPath()
        
        return roundedRect
    }
}
