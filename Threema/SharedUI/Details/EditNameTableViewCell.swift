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

/// Cell with a textfield to edit a person's first or last name or a group name
final class EditNameTableViewCell: ThemedCodeTableViewCell {
    
    weak var delegate: EditNameTableViewCellDelegate?
    
    private let nameInputView = EditNameInputView()
    
    override func configureCell() {
        super.configureCell()
        
        selectionStyle = .none
        
        contentView.addSubview(nameInputView)
        nameInputView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            nameInputView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            nameInputView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            nameInputView.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
            nameInputView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
        ])
        
        nameInputView.onTextChanged = { [weak self] text in
            guard let self else {
                return
            }
            delegate?.editNameTableViewCell(self, didChangeTextTo: text)
        }
    }
    
    var nameType: EditNameInputView.NameType {
        get {
            nameInputView.nameType
        }
        set {
            nameInputView.nameType = newValue
        }
    }
    
    var name: String? {
        get {
            nameInputView.name
        }
        set {
            nameInputView.name = newValue
        }
    }
    
    override var canBecomeFirstResponder: Bool { true }
    
    override func becomeFirstResponder() -> Bool {
        nameInputView.becomeFirstResponder()
    }
}

// MARK: - Reusable

extension EditNameTableViewCell: Reusable { }
