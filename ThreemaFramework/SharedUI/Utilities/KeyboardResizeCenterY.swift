//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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

public class KeyboardResizeCenterY {
    let parentView: UIView
    let resizeView: UIView
    var defaultCenterY: NSLayoutConstraint
    var offsetCenterY: NSLayoutConstraint?
    
    public init(parent: UIView, resize: UIView) {
        self.parentView = parent
        self.resizeView = resize
        
        self.defaultCenterY = NSLayoutConstraint(
            item: resizeView,
            attribute: NSLayoutConstraint.Attribute.centerY,
            relatedBy: NSLayoutConstraint.Relation.equal,
            toItem: parentView,
            attribute: NSLayoutConstraint.Attribute.centerY,
            multiplier: 1.0,
            constant: 0
        )
        
        parentView.addConstraint(defaultCenterY)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardDidShow),
            name: UIResponder.keyboardDidShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func keyboardDidShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?
            .cgRectValue {
            let offset: CGFloat = UIScreen.main.bounds.height - resizeView.frame.maxY - keyboardSize.height - 10
            if offset < 0 {
                offsetCenterY = NSLayoutConstraint(
                    item: resizeView,
                    attribute: NSLayoutConstraint.Attribute.centerY,
                    relatedBy: NSLayoutConstraint.Relation.equal,
                    toItem: parentView,
                    attribute: NSLayoutConstraint.Attribute.centerY,
                    multiplier: 1.0,
                    constant: offset
                )
                
                parentView.removeConstraint(defaultCenterY)
                parentView.addConstraint(offsetCenterY!)
            }
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        if let offsetCenterY = offsetCenterY {
            parentView.removeConstraint(offsetCenterY)
        }
        parentView.addConstraint(defaultCenterY)
    }
}
