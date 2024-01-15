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

/// Custom table view header with optional action
final class DetailsSectionHeaderView: ThemedCodeTableViewHeaderFooterView {

    // MARK: - Public properties
    
    /// Title shown left aligned
    ///
    /// This should always be set.
    var title: String? {
        didSet {
            titleLabel.text = title
        }
    }
    
    /// Optional action
    ///
    /// Provide a `title` and `action`.
    var action: Details.Action? {
        didSet {
            
            // The action button is always shown, but if `action` is `nil` the text is empty and interaction
            // disabled. This is due to the fact that the button has a fixed height that might be higher than
            // the `titleLabel` and thus we would get different heights for the `containerStack`. To keep it
            // adaptive to text size, but to get a constant height for this header we never hide the button.
            
            guard let action else {
                actionButton.setTitle("", for: .normal)
                actionButton.isUserInteractionEnabled = false
                actionButton.isAccessibilityElement = false
                
                // To prevent weird spacing with a vertical stack we hide the button for accessibility
                // size categories
                if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
                    actionButton.isHidden = true
                }
                
                return
            }
            
            actionButton.setTitle(action.title, for: .normal)
            actionButton.isUserInteractionEnabled = true
            actionButton.isAccessibilityElement = true
            
            if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
                actionButton.isHidden = false
            }
        }
    }
    
    // MARK: - Private properties
    
    // MARK: Subviews
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            label.numberOfLines = 0
        }
                
        return label
    }()
    
    private lazy var actionButton: UIButton = {
        let button = UIButton(type: .system)
        
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .subheadline)
        
        button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        
        // See `action` for reasoning. As default no action is expected.
        button.setTitle("", for: .normal)
        button.isUserInteractionEnabled = false
        
        button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        button.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        
        return button
    }()
    
    private lazy var containerStack: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [titleLabel, actionButton])
        
        stackView.axis = .horizontal
        stackView.alignment = .firstBaseline
        stackView.spacing = 8
        stackView.distribution = .equalSpacing
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            stackView.axis = .vertical
            stackView.alignment = .leading
        }
                
        return stackView
    }()
    
    // MARK: - Lifecycle
    
    override func configureView() {
        super.configureView()
        
        contentView.addSubview(containerStack)
                
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            containerStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerStack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            containerStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            containerStack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
        ])
    }
    
    override func updateColors() {
        super.updateColors()
    }
    
    // MARK: - Action
    
    @objc private func buttonTapped() {
        action?.run(actionButton)
    }
}

// MARK: - Reusable

extension DetailsSectionHeaderView: Reusable { }
