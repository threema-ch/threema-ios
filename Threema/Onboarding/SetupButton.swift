//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2025 Threema GmbH
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

@IBDesignable class SetupButton: UIButton {
    
    @IBInspectable var cancelStyle = false {
        didSet {
            setup()
        }
    }
    
    @IBInspectable var accentColor: UIColor = .tintColor {
        didSet {
            setup()
        }
    }
    
    @IBInspectable var textColor: UIColor = Colors.textSetup {
        didSet {
            setup()
        }
    }
    
    var deactivated: Bool {
        set {
            isEnabled = !newValue
            setup()
        }
        get {
            isEnabled
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
        titleLabel?.font = UIFont.systemFont(ofSize: 16.0)

        alpha = isEnabled ? 1.0 : 0.5
        isUserInteractionEnabled = isEnabled
        layer.cornerRadius = 3
        addConstraint(NSLayoutConstraint(
            item: self,
            attribute: .height,
            relatedBy: .equal,
            toItem: nil,
            attribute: .notAnAttribute,
            multiplier: 0.0,
            constant: 36
        ))
        
        // calculate disabled color
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        accentColor.getRed(&red, green: &green, blue: &blue, alpha: nil)
        let accentColorDisabled = UIColor(red: red, green: green, blue: blue, alpha: 0.5)
        
        if cancelStyle {
            backgroundColor = .clear
            setTitleColor(accentColor, for: .normal)
            layer.borderWidth = 1
            layer.borderColor = isEnabled ? accentColor.cgColor : accentColorDisabled.cgColor
        }
        else {
            backgroundColor = isEnabled ? accentColor : accentColorDisabled
            setTitleColor(Colors.textProminentButtonWizard, for: .normal)
        }
    }
}
