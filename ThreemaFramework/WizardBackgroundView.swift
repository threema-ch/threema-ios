//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2022 Threema GmbH
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

@objc public class WizardBackgroundView: UIView {
    @objc override public func draw(_ rect: CGRect) {
        super.draw(rect)
        
        self.drawCanvas1(frame: rect )
    }
    
    func drawCanvas1(frame: CGRect = CGRect(x: 0, y: 0, width: 2890, height: 1380)) {
        //// General Declarations
        // This non-generic function dramatically improves compilation times of complex expressions.
        func fastFloor(_ x: CGFloat) -> CGFloat { return floor(x) }

        //// Color Declarations
        let fillColor = UIColor(red: 0.169, green: 0.169, blue: 0.169, alpha: 1.000)
        let fillColor2 = UIColor(red: 0.000, green: 0.000, blue: 0.000, alpha: 0.130)
        let fillColor3 = UIColor(red: 0.000, green: 0.000, blue: 0.000, alpha: 0.200)
        let fillColor4 = UIColor(red: 0.000, green: 0.000, blue: 0.000, alpha: 0.180)
        let fillColor5 = UIColor(red: 0.000, green: 0.000, blue: 0.000, alpha: 0.350)
        let fillColor6 = UIColor(red: 0.000, green: 0.000, blue: 0.000, alpha: 0.250)
        let fillColor7 = UIColor(red: 0.000, green: 0.000, blue: 0.000, alpha: 0.500)


        //// Subframes
        let wizardBgpdfGroup: CGRect = CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height)


        //// WizardBg.pdf Group
        //// Rectangle Drawing
        let rectanglePath = UIBezierPath(rect: CGRect(x: wizardBgpdfGroup.minX + fastFloor(wizardBgpdfGroup.width * 0.00000 + 0.5), y: wizardBgpdfGroup.minY + fastFloor(wizardBgpdfGroup.height * 0.00000 + 0.5), width: fastFloor(wizardBgpdfGroup.width * 1.00000 + 0.5) - fastFloor(wizardBgpdfGroup.width * 0.00000 + 0.5), height: fastFloor(wizardBgpdfGroup.height * 1.00000 + 0.5) - fastFloor(wizardBgpdfGroup.height * 0.00000 + 0.5)))
        fillColor.setFill()
        rectanglePath.fill()


        //// Bezier Drawing
        let bezierPath = UIBezierPath()
        bezierPath.move(to: CGPoint(x: wizardBgpdfGroup.minX + 0.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 0.12246 * wizardBgpdfGroup.height))
        bezierPath.addLine(to: CGPoint(x: wizardBgpdfGroup.minX + 1.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 0.23700 * wizardBgpdfGroup.height))
        bezierPath.addLine(to: CGPoint(x: wizardBgpdfGroup.minX + 1.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 1.00000 * wizardBgpdfGroup.height))
        bezierPath.addLine(to: CGPoint(x: wizardBgpdfGroup.minX + 0.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 1.00000 * wizardBgpdfGroup.height))
        bezierPath.addLine(to: CGPoint(x: wizardBgpdfGroup.minX + 0.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 0.12246 * wizardBgpdfGroup.height))
        bezierPath.addLine(to: CGPoint(x: wizardBgpdfGroup.minX + 0.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 0.12246 * wizardBgpdfGroup.height))
        bezierPath.close()
        bezierPath.usesEvenOddFillRule = true
        fillColor2.setFill()
        bezierPath.fill()


        //// Bezier 2 Drawing
        let bezier2Path = UIBezierPath()
        bezier2Path.move(to: CGPoint(x: wizardBgpdfGroup.minX + 1.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 0.00000 * wizardBgpdfGroup.height))
        bezier2Path.addLine(to: CGPoint(x: wizardBgpdfGroup.minX + 1.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 1.00000 * wizardBgpdfGroup.height))
        bezier2Path.addLine(to: CGPoint(x: wizardBgpdfGroup.minX + 0.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 1.00000 * wizardBgpdfGroup.height))
        bezier2Path.addLine(to: CGPoint(x: wizardBgpdfGroup.minX + 0.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 0.62747 * wizardBgpdfGroup.height))
        bezier2Path.addLine(to: CGPoint(x: wizardBgpdfGroup.minX + 0.66701 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 0.00000 * wizardBgpdfGroup.height))
        bezier2Path.addLine(to: CGPoint(x: wizardBgpdfGroup.minX + 1.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 0.00000 * wizardBgpdfGroup.height))
        bezier2Path.addLine(to: CGPoint(x: wizardBgpdfGroup.minX + 1.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 0.00000 * wizardBgpdfGroup.height))
        bezier2Path.close()
        bezier2Path.usesEvenOddFillRule = true
        fillColor3.setFill()
        bezier2Path.fill()


        //// Bezier 3 Drawing
        let bezier3Path = UIBezierPath()
        bezier3Path.move(to: CGPoint(x: wizardBgpdfGroup.minX + 0.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 0.26232 * wizardBgpdfGroup.height))
        bezier3Path.addLine(to: CGPoint(x: wizardBgpdfGroup.minX + 1.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 0.69998 * wizardBgpdfGroup.height))
        bezier3Path.addLine(to: CGPoint(x: wizardBgpdfGroup.minX + 1.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 1.00000 * wizardBgpdfGroup.height))
        bezier3Path.addLine(to: CGPoint(x: wizardBgpdfGroup.minX + 0.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 1.00000 * wizardBgpdfGroup.height))
        bezier3Path.addLine(to: CGPoint(x: wizardBgpdfGroup.minX + 0.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 0.26232 * wizardBgpdfGroup.height))
        bezier3Path.addLine(to: CGPoint(x: wizardBgpdfGroup.minX + 0.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 0.26232 * wizardBgpdfGroup.height))
        bezier3Path.close()
        bezier3Path.usesEvenOddFillRule = true
        fillColor4.setFill()
        bezier3Path.fill()


        //// Bezier 4 Drawing
        let bezier4Path = UIBezierPath()
        bezier4Path.move(to: CGPoint(x: wizardBgpdfGroup.minX + 1.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 0.36531 * wizardBgpdfGroup.height))
        bezier4Path.addLine(to: CGPoint(x: wizardBgpdfGroup.minX + 1.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 1.00000 * wizardBgpdfGroup.height))
        bezier4Path.addLine(to: CGPoint(x: wizardBgpdfGroup.minX + 0.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 1.00000 * wizardBgpdfGroup.height))
        bezier4Path.addLine(to: CGPoint(x: wizardBgpdfGroup.minX + 0.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 0.83415 * wizardBgpdfGroup.height))
        bezier4Path.addLine(to: CGPoint(x: wizardBgpdfGroup.minX + 1.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 0.36531 * wizardBgpdfGroup.height))
        bezier4Path.addLine(to: CGPoint(x: wizardBgpdfGroup.minX + 1.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 0.36531 * wizardBgpdfGroup.height))
        bezier4Path.close()
        bezier4Path.usesEvenOddFillRule = true
        fillColor5.setFill()
        bezier4Path.fill()


        //// Bezier 5 Drawing
        let bezier5Path = UIBezierPath()
        bezier5Path.move(to: CGPoint(x: wizardBgpdfGroup.minX + 0.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 0.69783 * wizardBgpdfGroup.height))
        bezier5Path.addLine(to: CGPoint(x: wizardBgpdfGroup.minX + 1.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 0.92059 * wizardBgpdfGroup.height))
        bezier5Path.addLine(to: CGPoint(x: wizardBgpdfGroup.minX + 1.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 1.00000 * wizardBgpdfGroup.height))
        bezier5Path.addLine(to: CGPoint(x: wizardBgpdfGroup.minX + 0.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 1.00000 * wizardBgpdfGroup.height))
        bezier5Path.addLine(to: CGPoint(x: wizardBgpdfGroup.minX + 0.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 0.69783 * wizardBgpdfGroup.height))
        bezier5Path.addLine(to: CGPoint(x: wizardBgpdfGroup.minX + 0.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 0.69783 * wizardBgpdfGroup.height))
        bezier5Path.close()
        bezier5Path.usesEvenOddFillRule = true
        fillColor6.setFill()
        bezier5Path.fill()


        //// Bezier 6 Drawing
        let bezier6Path = UIBezierPath()
        bezier6Path.move(to: CGPoint(x: wizardBgpdfGroup.minX + 1.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 0.62617 * wizardBgpdfGroup.height))
        bezier6Path.addLine(to: CGPoint(x: wizardBgpdfGroup.minX + 1.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 0.99968 * wizardBgpdfGroup.height))
        bezier6Path.addLine(to: CGPoint(x: wizardBgpdfGroup.minX + 0.50000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 1.00000 * wizardBgpdfGroup.height))
        bezier6Path.addLine(to: CGPoint(x: wizardBgpdfGroup.minX + 1.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 0.62617 * wizardBgpdfGroup.height))
        bezier6Path.addLine(to: CGPoint(x: wizardBgpdfGroup.minX + 1.00000 * wizardBgpdfGroup.width, y: wizardBgpdfGroup.minY + 0.62617 * wizardBgpdfGroup.height))
        bezier6Path.close()
        bezier6Path.usesEvenOddFillRule = true
        fillColor7.setFill()
        bezier6Path.fill()
    }
}
