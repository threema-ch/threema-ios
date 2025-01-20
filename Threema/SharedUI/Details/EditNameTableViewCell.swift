//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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

import ThreemaMacros
import UIKit

// MARK: Delegate

/// Get updates for changed names in a `EditNameTableViewCell`
protocol EditNameTableViewCellDelegate: AnyObject {
    /// Called whenever the name in the textfield did change
    ///
    /// - Parameters:
    ///   - editNameTableViewCell: The cell itself
    ///   - newText: The new name
    func editNameTableViewCell(_ editNameTableViewCell: EditNameTableViewCell, didChangeTextTo newText: String?)
}

// MARK: - EditNameTableViewCell.Configuration

extension EditNameTableViewCell {
    private struct Configuration: DetailsConfiguration { }
}

/// Cell with a textfield to edit a person's first or last name or a group name
class EditNameTableViewCell: ThemedCodeTableViewCell {
    
    // MARK: - Types
    
    enum NameType {
        case firstName
        case lastName
        case groupName
        case distributionListName
    }
    
    // MARK: - Public properties
    
    /// Type of name in this cell
    var nameType: NameType = .firstName {
        didSet {
            switch nameType {
            case .firstName:
                nameTextField.placeholder = #localize("first_name_placeholder")
                nameTextField.textContentType = .givenName
                maxNumberOfUTF8Bytes = kMaxFirstOrLastNameLength
            case .lastName:
                nameTextField.placeholder = #localize("last_name_placeholder")
                nameTextField.textContentType = .familyName
                maxNumberOfUTF8Bytes = kMaxFirstOrLastNameLength
            case .groupName:
                nameTextField.placeholder = #localize("group_name_placeholder")
                nameTextField.textContentType = .none
                maxNumberOfUTF8Bytes = kMaxGroupNameLength
            case .distributionListName:
                nameTextField.placeholder = #localize("distribution_list_name_placeholder")
                nameTextField.textContentType = .none
                maxNumberOfUTF8Bytes = kMaxGroupNameLength
            }
        }
    }
    
    /// Set to initially shown name
    var name: String? {
        get {
            nameTextField.text
        }
        
        set {
            nameTextField.text = newValue
        }
    }
    
    /// Get updates when name changed
    weak var delegate: EditNameTableViewCellDelegate?
    
    // MARK: - Private properties
    
    private var maxNumberOfUTF8Bytes: Int?
    
    private let configuration = Configuration()
    
    // MARK: Subview
    
    private lazy var nameTextField: UITextField = {
        let textField = UITextField()
        
        textField.font = configuration.nameFont
        textField.adjustsFontSizeToFitWidth = true
        textField.minimumFontSize = UIFont.preferredFont(forTextStyle: .body).pointSize
        
        textField.becomeFirstResponder()
        textField.autocapitalizationType = .words
        textField.clearButtonMode = .whileEditing
        
        textField.textColor = .label
        
        textField.delegate = self
        
        return textField
    }()
    
    // MARK: - Configuration
    
    override func configureCell() {
        super.configureCell()
        
        selectionStyle = .none
        
        contentView.addSubview(nameTextField)
        nameTextField.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            nameTextField.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            nameTextField.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            nameTextField.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
            nameTextField.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
        ])
    }
    
    // MARK: - Responder chain
    
    override var canBecomeFirstResponder: Bool {
        true
    }
    
    override func becomeFirstResponder() -> Bool {
        nameTextField.becomeFirstResponder()
    }
}

// MARK: - UITextFieldDelegate

extension EditNameTableViewCell: UITextFieldDelegate {
    
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        // Limit number of UTF-8 bytes if there is any limit
        guard let maxNumberOfUTF8Bytes else {
            return true
        }
        
        let currentText = textField.text ?? ""
        guard let rangeToBeReplaced = Range(range, in: currentText) else {
            return false
        }
        let newText = currentText.replacingCharacters(in: rangeToBeReplaced, with: string)
        
        return newText.utf8.count <= maxNumberOfUTF8Bytes
    }
    
    func textFieldDidChangeSelection(_ textField: UITextField) {
        // Just calling this from `textField(_:shouldChangeCharactersIn:replacementString:)`
        // would miss the changes due to the custom clear button.
        delegate?.editNameTableViewCell(self, didChangeTextTo: textField.text)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Hide keyboard on return
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - Reusable

extension EditNameTableViewCell: Reusable { }
