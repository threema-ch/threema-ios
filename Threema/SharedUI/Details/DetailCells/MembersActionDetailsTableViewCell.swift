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

import UIKit

/// Use for actions shown inline along members
class MembersActionDetailsTableViewCell: ThemedCodeTableViewCell {
    
    // MARK: - Public properties
    
    var action: Details.Action? {
        didSet {
            guard let action else {
                return
            }
            
            if let imageName = action.imageName {
                var image = UIImage(systemName: imageName)
                if image == nil {
                    image = UIImage(named: imageName)
                }
                image = image?.applying(symbolWeight: .semibold, symbolScale: .large)
                
                assert(image != nil, "Symbol not found")
                iconImageView.image = image
            }
            else {
                assertionFailure("This should only be used with an icon")
            }
            
            labelLabel.text = action.title
            
            updateColors()
        }
    }
    
    // MARK: - Private configuration
    
    private lazy var cellConfiguration = CellConfiguration(size: .medium)
    
    // MARK: Subviews
    
    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        
        imageView.contentMode = .scaleAspectFill
                
        return imageView
    }()
    
    private lazy var iconBackgroundView: UIView = {
        let view = UIView()
        
        view.layer.cornerRadius = cellConfiguration.maxAvatarSize / 2
        
        view.heightAnchor.constraint(equalToConstant: cellConfiguration.maxAvatarSize).isActive = true
        view.widthAnchor.constraint(equalTo: view.heightAnchor).isActive = true
        view.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        return view
    }()
    
    private lazy var labelLabel: UILabel = {
        let label = UILabel()
        
        label.font = UIFont.preferredFont(forTextStyle: .title3)
        
        // We aim to only use one line but don't truncate if we don't fit on one line
        label.numberOfLines = 0
        
        return label
    }()
    
    private lazy var containerStack: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [iconBackgroundView, labelLabel])
        
        stackView.axis = .horizontal
        stackView.spacing = cellConfiguration.horizontalSpacing
        stackView.distribution = .fill
        stackView.alignment = .center
        
        return stackView
    }()
    
    // MARK: - Lifecycle
    
    override func configureCell() {
        super.configureCell()
        
        accessibilityTraits.insert(.button)
        
        // Configure icon with background
        iconBackgroundView.addSubview(iconImageView)
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: iconBackgroundView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconBackgroundView.centerYAnchor),
        ])
        
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
        
        action = nil
        iconImageView.image = nil
    }
    
    override func updateColors() {
        super.updateColors()

        iconImageView.tintColor = .primary
        iconBackgroundView.backgroundColor = Colors.secondary
        labelLabel.textColor = .primary
    }
    
    override public func layoutMarginsDidChange() {
        super.layoutMarginsDidChange()
        
        guard !traitCollection.preferredContentSizeCategory.isAccessibilityCategory else {
            separatorInset = .zero
            return
        }
        
        // Adjust separator inset
        let leftSeparatorInset = cellConfiguration.maxAvatarSize + cellConfiguration.horizontalSpacing
        separatorInset = UIEdgeInsets(top: 0, left: leftSeparatorInset, bottom: 0, right: 0)
    }
}

// MARK: - Reusable

extension MembersActionDetailsTableViewCell: Reusable { }
