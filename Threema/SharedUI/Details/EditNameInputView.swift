//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

// MARK: - EditNameInputView.Configuration

extension EditNameInputView {
    private struct Configuration: DetailsConfiguration { }
}

final class EditNameInputView: UIView {
    
    enum NameType {
        case nickname
        case firstName
        case lastName
        case groupName
        case distributionListName
    }
    
    var nameType: NameType = .firstName {
        didSet {
            switch nameType {
            case .nickname:
                nameTextField.placeholder = ProfileStore().profile.myIdentity.rawValue
                nameTextField.textContentType = .nickname
                maxNumberOfUTF8Bytes = kMaxNicknameLength
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
    
    var name: String? {
        get {
            nameTextField.text
        }
        set {
            nameTextField.text = newValue
        }
    }
    
    var onTextChanged: ((String?) -> Void)?
    
    private var maxNumberOfUTF8Bytes: Int?
    
    private let configuration = EditNameInputView.Configuration()
    
    private lazy var nameTextField: UITextField = {
        let textField = UITextField()
        
        textField.font = configuration.nameFont
        textField.adjustsFontSizeToFitWidth = true
        textField.minimumFontSize = UIFont.preferredFont(forTextStyle: .body).pointSize
        textField.autocapitalizationType = .words
        textField.clearButtonMode = .whileEditing
        textField.textColor = .label
        textField.delegate = self
        
        return textField
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(nameTextField)
        nameTextField.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            nameTextField.topAnchor.constraint(equalTo: topAnchor),
            nameTextField.leadingAnchor.constraint(equalTo: leadingAnchor),
            nameTextField.bottomAnchor.constraint(equalTo: bottomAnchor),
            nameTextField.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - UITextFieldDelegate

extension EditNameInputView: UITextFieldDelegate {
    
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        
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
        onTextChanged?(textField.text)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
