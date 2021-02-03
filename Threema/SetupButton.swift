//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2021 Threema GmbH
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
    
    @IBInspectable var cancelStyle: Bool = false {
        didSet {
            setup()
        }
    }
    
    @IBInspectable var accentColor: UIColor = Colors.mainThemeDark() {
        didSet {
            setup()
        }
    }
    
    @IBInspectable var textColor: UIColor = Colors.white() {
        didSet {
            setup()
        }
    }
    
    var deactivated: Bool {
        set {
            self.isEnabled = !newValue
            setup()
        }
        get {
            return self.isEnabled
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
        self.titleLabel?.font = UIFont.systemFont(ofSize: 16.0)

        self.alpha = self.isEnabled ? 1.0 : 0.5
        self.isUserInteractionEnabled = self.isEnabled
        self.layer.cornerRadius = 3
        self.addConstraint(NSLayoutConstraint(item: self, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 0.0, constant: 36))
        
        // calculate disabled color
        var red : CGFloat = 0
        var green : CGFloat = 0
        var blue : CGFloat = 0
        self.accentColor.getRed(&red, green: &green, blue: &blue, alpha: nil)
        let accentColorDisabled: UIColor = UIColor(red: red, green: green, blue: blue, alpha: 0.5)
        
        if self.cancelStyle {
            self.backgroundColor = .clear
            self.setTitleColor(self.accentColor, for: .normal)
            self.layer.borderWidth = 1
            self.layer.borderColor = self.isEnabled ? self.accentColor.cgColor : accentColorDisabled.cgColor
        } else {
            self.backgroundColor = self.isEnabled ? self.accentColor : accentColorDisabled
            self.setTitleColor(self.textColor, for: .normal)
        }
    }
}
