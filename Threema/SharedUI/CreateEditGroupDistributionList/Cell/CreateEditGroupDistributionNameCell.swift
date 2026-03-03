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

final class CreateEditGroupDistributionNameCell: UICollectionViewCell {
    
    // MARK: - Public properties
    
    var nameType: EditNameInputView.NameType {
        get { nameInputView.nameType }
        set { nameInputView.nameType = newValue }
    }
    
    var name: String? {
        get { nameInputView.name }
        set { nameInputView.name = newValue }
    }
    
    var onTextChanged: ((String?) -> Void)?
    
    // MARK: - Private properties
    
    private lazy var nameInputView = EditNameInputView()
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        contentView.addSubview(nameInputView)
        contentView.backgroundColor = .secondarySystemGroupedBackground
        contentView.layer.cornerRadius = 10
        contentView.layer.masksToBounds = true
        
        nameInputView.translatesAutoresizingMaskIntoConstraints = false
        nameInputView.backgroundColor = .clear
        
        NSLayoutConstraint.activate([
            nameInputView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 4),
            nameInputView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor, constant: 4),
            nameInputView.trailingAnchor.constraint(
                equalTo: contentView.layoutMarginsGuide.trailingAnchor,
                constant: -4
            ),
            nameInputView.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor, constant: -4),
        ])
        
        nameInputView.onTextChanged = { [weak self] text in
            self?.onTextChanged?(text)
        }
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        onTextChanged = nil
    }
}

// MARK: - Reusable

extension CreateEditGroupDistributionNameCell: Reusable { }
