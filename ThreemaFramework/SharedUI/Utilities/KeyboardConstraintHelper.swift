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

import Foundation
import UIKit

public enum KeyboardConstraintHelper {
    public static func updateLayoutForKeyboard(
        view: UIView,
        constraint: NSLayoutConstraint,
        notification: NSNotification,
        action: @escaping () -> Void,
        completion: ((Bool) -> Void)? = nil
    ) {
        guard let userInfo = notification.userInfo else {
            return
        }
        
        let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        let endFrameY = endFrame?.origin.y ?? 0
        
        var duration: TimeInterval = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?
            .doubleValue ?? 0
        
        let animationCurveRawNSN = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber
        let animationCurveRaw = animationCurveRawNSN?.uintValue ?? UIView.AnimationOptions.curveEaseInOut.rawValue
        let animationCurve = UIView.AnimationOptions(rawValue: animationCurveRaw)
        
        let constraintConstant: CGFloat
        
        if let endFrame = endFrame, endFrameY < UIScreen.main.bounds.size.height {
            let convertedEndframe = view.convert(endFrame, from: UIScreen.main.coordinateSpace)
            let intersection = view.frame.intersection(convertedEndframe).height
            constraintConstant = -max(
                intersection,
                0
            )
            
            // Extend the duration of the animation by the amount it takes the keyboard to animate across the safe area
            // We have previously used delay to do the same thing, but that completely broke the bitmoji keyboard.
            // I suspect that this was caused by the `layoutIfNeeded` call executed in `action` but didn't check very thoroughly.
            // Note that doing another layout pass immediately after receiving the keyboard change notification did not resolve the issue.
            duration += TimeInterval(view.safeAreaInsets.bottom * (0.25 / intersection) / 3)
        }
        else {
            constraintConstant = 0.0
        }
        
        constraint.constant = constraintConstant
        
        UIView.animate(
            withDuration: duration,
            delay: 0.0,
            options: animationCurve,
            animations: {
                action()
            },
            completion: completion
        )
    }
}
