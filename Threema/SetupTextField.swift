//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2020 Threema GmbH
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

@objc protocol SetupTextFieldDelegate {
    func editingChangedTextField(_ sender: SetupTextField, forEvent event: UIEvent) -> Void
    func primaryActionTriggered(_ sender: SetupTextField, forEvent event: UIEvent) -> Void
}

@IBDesignable class SetupTextField: UIView {
    
    private var currentDefaultText: String?
    
    //MARK: Control Properties

    @IBInspectable var showIcon: UIImage? {
        didSet {
            self.icon.image = showIcon?.withTint(Colors.white())
            self.icon.isHidden = false
            self.textBackground.frame = CGRect(x: 40, y: 0, width: self.frame.width - 40, height: self.frame.height)
            self.textField.frame = CGRect(x: 45, y: 5, width: 230, height: 30)
        }
    }
    
    @IBInspectable var placeholder: String? {
        didSet {
            let foregroundColor = [NSAttributedString.Key.foregroundColor: UIColor.lightGray] //THREEMA_COLOR_PLACEHOLDER
            self.textField.attributedPlaceholder = NSAttributedString(string: placeholder!, attributes: foregroundColor)
            self.textField.accessibilityLabel = placeholder
        }
    }
    
    @IBInspectable var defaultText: String? {
        didSet {
            self.currentDefaultText = defaultText
        }
    }
    
    @IBInspectable var capitalization: Int = 0 {
        didSet {
            if let type = UITextAutocapitalizationType(rawValue: capitalization) {
                self.textField.autocapitalizationType = type
            }
        }
    }
    
    @IBInspectable var keyboardType: Int = 0 {
        didSet {
            if let type = UIKeyboardType(rawValue: keyboardType) {
                self.textField.keyboardType = type
            }
        }
    }

    @IBInspectable var returnKey: Int = 0 {
        didSet {
            if let type = UIReturnKeyType(rawValue: returnKey) {
                self.textField.returnKeyType = type
            }
        }
    }
    
    @IBInspectable var secureTextEntry: Bool = false {
        didSet {
            self.textField.isSecureTextEntry = secureTextEntry
        }
    }
    
    var text: String? {
        get {
            return self.textField.text
        }
        set {
            self.textField.text = newValue
        }
    }
    
    override var isFirstResponder: Bool {
        get {
            return self.textField.isFirstResponder
        }
    }
    
    //MARK: delegate control events
    
    weak var delegate: SetupTextFieldDelegate?
    
    @objc func editingChanged(_ sender: UITextField, forEvent event: UIEvent) {
        self.delegate?.editingChangedTextField(self, forEvent: event)
    }
    
    @objc private func touchDown(_ sender: UITextField, forEvent event: UIEvent) {
        guard let current = self.currentDefaultText, let currentText = sender.text, currentText.count == 0 else {
            return
        }
        sender.text = current
    }
    
    @objc private func primaryActionTriggered(_ sender: UITextField, forEvent event: UIEvent) {
        self.delegate?.primaryActionTriggered(self, forEvent: event)
    }
    
    //MARK: Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }
    
    @discardableResult
    override func becomeFirstResponder() -> Bool {
        return self.textField.becomeFirstResponder()
    }
    
    @discardableResult
    override func resignFirstResponder() -> Bool {
        return self.textField.resignFirstResponder()
    }
        
    private let icon: UIImageView = {
        let icon = UIImageView()
        icon.isHidden = true
        icon.frame = CGRect(x: 11, y: 11, width: 18, height: 18)
        return icon
    }()
    
    private let textBackground: UIView = {
        let background = UIView()
        background.alpha = 0.1
        background.backgroundColor = .white
        background.layer.borderWidth = 0.5
        background.layer.borderColor = UIColor(red:1.0, green:1.0, blue:1.0, alpha:0.1).cgColor
        background.layer.cornerRadius = 3
        return background
    }()
    
    private let textField: UITextField = {
        let field = UITextField()
        field.textColor = UIColor.white
        field.tintColor = UIColor.white
        field.backgroundColor = .clear
        field.borderStyle = .none
        field.textAlignment = .left
        field.font = UIFont.systemFont(ofSize: 16.0, weight: .light)
        field.autocorrectionType = UITextAutocorrectionType.no
        field.spellCheckingType = UITextSpellCheckingType.no
        field.keyboardAppearance = UIKeyboardAppearance.dark
        return field
    }()
 
    //MARK: Private Methods
    
    private func setup() {
        self.backgroundColor = UIColor.clear
        
        let background = UIView(frame: CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height))
        background.backgroundColor = UIColor.clear
        background.layer.borderWidth = 0.5
        background.layer.borderColor = UIColor(red:1.0, green:1.0, blue:1.0, alpha:0.1).cgColor
        background.layer.cornerRadius = 3
        
        self.textBackground.frame = CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height)
        self.textField.frame = CGRect(x: 5, y: 5, width: 270, height: 30)
        self.textField.addTarget(self, action: #selector(editingChanged), for: .editingChanged)
        self.textField.addTarget(self, action: #selector(touchDown), for: .touchDown)
        self.textField.addTarget(self, action: #selector(primaryActionTriggered), for: .primaryActionTriggered)
        self.textField.delegate = self

        self.textField.tintColor = Colors.mainThemeDark()

        self.addSubview(background)
        self.addSubview(self.icon)
        self.addSubview(textBackground)
        self.addSubview(self.textField)
    }

}

extension SetupTextField: UITextFieldDelegate {
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        // Check if it has lowercase characters
        if self.capitalization != 0 && string.rangeOfCharacter(from: CharacterSet.lowercaseLetters) != nil {
            if let textCurrent = textField.text,
                let rangeCurrent = Range<String.Index>(range, in: textCurrent) {
                
                // Get current cursor position
                let selectedTextRangeCurrent = textField.selectedTextRange
                
                // Replace lowercase character with uppercase character
                textField.text = textField.text?.replacingCharacters(in: rangeCurrent, with: string.uppercased())
                
                if let selectedTextRangeCurrent = selectedTextRangeCurrent {
                    // Set current cursor position, if cursor position + 1 is valid
                    if let newPosition = textField.position(from: selectedTextRangeCurrent.start, offset: 1) {
                        textField.selectedTextRange = textField.textRange(from: newPosition, to: newPosition)
                    }
                }
            }
            return false
        }
        
        return true;
    }
}
