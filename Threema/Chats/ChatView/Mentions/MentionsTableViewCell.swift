//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2024 Threema GmbH
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
import ThreemaMacros

class MentionsTableViewCell: ThemedCodeTableViewCell {
    // MARK: Subviews
    
    public lazy var profilePictureView: ProfilePictureImageView = {
        let profilePictureView = ProfilePictureImageView()
        profilePictureView.translatesAutoresizingMaskIntoConstraints = false
        profilePictureView.heightAnchor.constraint(lessThanOrEqualToConstant: 35).isActive = true
        profilePictureView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return profilePictureView
    }()
    
    public lazy var nameLabel: UILabel = {
        let label = UILabel()
        
        label.font = UIFont.preferredFont(forTextStyle: .body)
        
        // We aim to only use one line but don't truncate if we don't fit on one line
        label.numberOfLines = 0
        
        return label
    }()
    
    private lazy var leftContainerStack: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [profilePictureView, nameLabel])
        
        stackView.axis = .horizontal
        stackView.spacing = 10
        stackView.distribution = .fill
        stackView.alignment = .center
        
        return stackView
    }()
    
    private lazy var containerStack: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [leftContainerStack])
        
        stackView.axis = .horizontal
        stackView.spacing = 20
        stackView.distribution = .fill
        stackView.alignment = .center
        
        return stackView
    }()
    
    override func configureCell() {
        super.configureCell()
        
        configureLayout()
        configureAccessibility()
    }
    
    private func configureAccessibility() {
        accessibilityHint = #localize("mentions_table_view_cell_accessibility_hint")
    }
    
    private func configureLayout() {
        // Configure container stack
        contentView.addSubview(containerStack)
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            containerStack.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            containerStack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            containerStack.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
            containerStack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
        ])
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.text = ""
    }
    
    override func updateColors() {
        super.updateColors()
        
        backgroundColor = Colors.backgroundChatBar
        nameLabel.textColor = Colors.text
    }
}

// MARK: - Reusable

extension MentionsTableViewCell: Reusable { }
