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

final class ContactGridContactCell: UICollectionViewCell {
    
    // MARK: - Constants
    
    private enum Constants {
        static let spacing: CGFloat = 8
    }
    
    // MARK: - Private properties
    
    var onClear: (() -> Void)?

    // MARK: - Private properties
    
    private lazy var clearButton: OpaqueDeleteButton = {
        let button = OpaqueDeleteButton { [weak self] _ in
            self?.onClear?()
        }
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var profileImageView: ProfilePictureImageView = {
        let imageView = ProfilePictureImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentHuggingPriority(.required, for: .vertical)
        imageView.setContentCompressionResistancePriority(.required, for: .vertical)
        imageView.contentMode = .top
        return imageView
    }()

    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .vertical)
        label.numberOfLines = 2
        label.textAlignment = .center
        label.contentMode = .top
        label.font = .preferredFont(forTextStyle: .caption1)
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    private lazy var stackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [profileImageView, nameLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Constants.spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // MARK: - Accessibility
    
    override var isAccessibilityElement: Bool {
        get { true }
        set { }
    }

    override var accessibilityLabel: String? {
        get { nameLabel.text }
        set { }
    }

    override var accessibilityTraits: UIAccessibilityTraits {
        get { [.button] }
        set { }
    }

    override var accessibilityCustomActions: [UIAccessibilityCustomAction]? {
        get {
            guard onClear != nil else {
                return nil
            }

            return [
                UIAccessibilityCustomAction(
                    name: #localize("accessibility_remove_contact"),
                    target: self,
                    selector: #selector(accessibilityRemoveContact)
                ),
            ]
        }
        set { }
    }

    @objc private func accessibilityRemoveContact() -> Bool {
        onClear?()
        return true
    }

    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        contentView.addSubview(stackView)
        contentView.addSubview(clearButton)

        NSLayoutConstraint.activate([
            clearButton.topAnchor.constraint(equalTo: contentView.topAnchor),
            clearButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 8),

            profileImageView.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            profileImageView.heightAnchor.constraint(equalTo: profileImageView.widthAnchor),

            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
        
        clearButton.addAction(UIAction { [weak self] _ in
            self?.handleClearButtonTap()
        }, for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        onClear = nil
    }
    
    // MARK: - Configuration
    
    func configureForSizing(with text: NSAttributedString) {
        nameLabel.attributedText = text
    }

    func configure(for contact: Contact) {
        nameLabel.attributedText = contact.attributedDisplayName
        profileImageView.info = .contact(contact)
    }
    
    // MARK: - Action
    
    private func handleClearButtonTap() {
        onClear?()
    }
}

// MARK: - Reusable

extension ContactGridContactCell: Reusable { }
