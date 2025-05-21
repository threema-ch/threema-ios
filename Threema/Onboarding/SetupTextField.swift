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

@objc protocol SetupTextFieldDelegate {
    func editingChangedTextField(_ sender: SetupTextField, forEvent event: UIEvent) -> Void
    func primaryActionTriggered(_ sender: SetupTextField, forEvent event: UIEvent) -> Void
}

@IBDesignable class SetupTextField: UIView {
    
    private var currentDefaultText: String?
    private var isMobile = false
    private var isID = false
    
    // MARK: Control Properties

    @IBInspectable var showIcon: UIImage? {
        didSet {
            icon.image = showIcon?.withTint(Colors.textSetup)
            icon.tintColor = Colors.textSetup
            icon.isHidden = false
            textBackground.frame = CGRect(x: 40, y: 0, width: frame.width - 40, height: frame.height)
            textField.frame = CGRect(x: 45, y: 5, width: 230, height: 30)
        }
    }
    
    @IBInspectable var placeholder: String? {
        didSet {
            let foregroundColor =
                [NSAttributedString.Key.foregroundColor: UIColor.lightGray] // THREEMA_COLOR_PLACEHOLDER
            textField.attributedPlaceholder = NSAttributedString(string: placeholder!, attributes: foregroundColor)
            textField.accessibilityLabel = placeholder
        }
    }
    
    @IBInspectable var defaultText: String? {
        didSet {
            currentDefaultText = defaultText
        }
    }
    
    @IBInspectable var capitalization = 0 {
        didSet {
            if let type = UITextAutocapitalizationType(rawValue: capitalization) {
                textField.autocapitalizationType = type
            }
        }
    }
    
    @IBInspectable var keyboardType = 0 {
        didSet {
            if let type = UIKeyboardType(rawValue: keyboardType) {
                textField.keyboardType = type
            }
        }
    }

    @IBInspectable var returnKey = 0 {
        didSet {
            if let type = UIReturnKeyType(rawValue: returnKey) {
                textField.returnKeyType = type
            }
        }
    }
    
    @IBInspectable var secureTextEntry = false {
        didSet {
            textField.isSecureTextEntry = secureTextEntry
        }
    }
    
    var text: String? {
        get {
            textField.text
        }
        set {
            textField.text = newValue
        }
    }
    
    override var accessibilityIdentifier: String? {
        get {
            textField.accessibilityIdentifier
        }
        
        set {
            textField.accessibilityIdentifier = newValue
        }
    }
    
    var mobile: Bool {
        get {
            isMobile
        }
        set {
            isMobile = newValue
        }
    }
    
    var threemaID: Bool {
        get {
            isID
        }
        set {
            isID = newValue
        }
    }
    
    override var isFirstResponder: Bool {
        textField.isFirstResponder
    }
    
    // MARK: delegate control events
    
    weak var delegate: SetupTextFieldDelegate?
    
    @objc func editingChanged(_ sender: UITextField, forEvent event: UIEvent) {
        delegate?.editingChangedTextField(self, forEvent: event)
    }
    
    @objc private func touchDown(_ sender: UITextField, forEvent event: UIEvent) {
        guard let current = currentDefaultText, let currentText = sender.text, currentText.isEmpty else {
            return
        }
        sender.text = current
    }
    
    @objc private func primaryActionTriggered(_ sender: UITextField, forEvent event: UIEvent) {
        delegate?.primaryActionTriggered(self, forEvent: event)
    }
    
    // MARK: Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    @discardableResult
    override func becomeFirstResponder() -> Bool {
        textField.becomeFirstResponder()
    }
    
    @discardableResult
    override func resignFirstResponder() -> Bool {
        textField.resignFirstResponder()
    }
        
    private let icon: UIImageView = {
        let icon = UIImageView()
        icon.isHidden = true
        icon.frame = CGRect(x: 11, y: 11, width: 18, height: 18)
        icon.contentMode = .scaleAspectFit
        return icon
    }()
    
    private let textBackground: UIView = {
        let background = UIView()
        background.alpha = 0.1
        background.backgroundColor = .white
        background.layer.borderWidth = 0.5
        background.layer.borderColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.1).cgColor
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
 
    // MARK: Private Methods
    
    private func setup() {
        backgroundColor = UIColor.clear
        
        let background = UIView(frame: CGRect(x: 0, y: 0, width: frame.width, height: frame.height))
        background.backgroundColor = UIColor.clear
        background.layer.borderWidth = 0.5
        background.layer.borderColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.1).cgColor
        background.layer.cornerRadius = 3
        
        textBackground.frame = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
        textField.frame = CGRect(x: 5, y: 5, width: 270, height: 30)
        textField.addTarget(self, action: #selector(editingChanged), for: .editingChanged)
        textField.addTarget(self, action: #selector(touchDown), for: .touchDown)
        textField.addTarget(self, action: #selector(primaryActionTriggered), for: .primaryActionTriggered)
        textField.delegate = self

        textField.tintColor = .tintColor

        addSubview(background)
        addSubview(icon)
        addSubview(textBackground)
        addSubview(textField)
    }
}

// MARK: - UITextFieldDelegate

extension SetupTextField: UITextFieldDelegate {
    
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        if isMobile {
            var allowedCharacters = CharacterSet.decimalDigits
            allowedCharacters.insert("+")
            let characterSet = CharacterSet(charactersIn: string)
            return allowedCharacters.isSuperset(of: characterSet)
        }
        else if isID, let count = textField.text?.count, count >= 8, !string.isEmpty {
            return false
        }
        // Check if it has lowercase characters
        if capitalization != 0, string.rangeOfCharacter(from: CharacterSet.lowercaseLetters) != nil {
            if let textCurrent = textField.text,
               let rangeCurrent = Range<String.Index>(range, in: textCurrent) {
                
                // Get current cursor position
                let selectedTextRangeCurrent = textField.selectedTextRange
                
                // Replace lowercase character with uppercase character
                textField.text = textField.text?.replacingCharacters(in: rangeCurrent, with: string.uppercased())
                
                if let selectedTextRangeCurrent {
                    // Set current cursor position, if cursor position + 1 is valid
                    if let newPosition = textField.position(from: selectedTextRangeCurrent.start, offset: 1) {
                        textField.selectedTextRange = textField.textRange(from: newPosition, to: newPosition)
                    }
                }
            }
            return false
        }
        
        return true
    }
}
