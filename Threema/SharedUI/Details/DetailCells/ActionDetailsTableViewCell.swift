//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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

// Note: No need to adjust dynamic type properties as cells are newly initialized after dynamic type changes
class ActionDetailsTableViewCell: ThemedCodeTableViewCell {
    
    // MARK: - Public properties
    
    var action: Details.Action? {
        didSet {
            guard let action = action else {
                return
            }
            
            if let imageName = action.imageName {
                let image = BundleUtil.imageNamed("\(imageName)_regular.L")
                assert(image != nil, "Use SF Symbol: regular L")
                iconImageView.image = image
            }
            
            labelLabel.text = action.title
            isUserInteractionEnabled = !action.disabled
            
            updateColors()
            updateIcon()
            updateTextAlignment()
        }
    }
    
    // MARK: - Private properties
    
    // Size configuration
    private let minCellHeight: CGFloat = 44
    
    private let iconCenterFromLeadingMargin: CGFloat = 12
    private let defaultLargeIconHeight: CGFloat = 28
    private let labelOffsetFromIconCenter: CGFloat = 28
    
    private let defaultTopAndBottomMargin: CGFloat = 10
    
    // MARK: Constraints
    
    // Constraints for cell with icon
    private var iconViewConstraints = [NSLayoutConstraint]()
    // Constraints for cell without icon
    private var noIconViewConstraints = [NSLayoutConstraint]()
    
    // MARK: Subviews
    
    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        
        imageView.contentMode = .scaleAspectFill
        
        let scaledHeight = UIFontMetrics.default.scaledValue(for: defaultLargeIconHeight)
        imageView.heightAnchor.constraint(equalToConstant: scaledHeight).isActive = true
        
        return imageView
    }()
    
    private lazy var labelLabel: UILabel = {
        let label = UILabel()
        
        label.font = UIFont.preferredFont(forTextStyle: .body)
        
        // We aim to only use one line but don't truncate if we don't fit on one line
        label.numberOfLines = 0
        
        return label
    }()
    
    // MARK: - Lifecycle
    
    override func configureCell() {
        super.configureCell()
        
        accessibilityTraits.insert(.button)
        
        contentView.addSubview(iconImageView)
        contentView.addSubview(labelLabel)
        
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        labelLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let scaledTopAndBottomMargin = UIFontMetrics.default.scaledValue(for: defaultTopAndBottomMargin)
        let minLabelHeight = minCellHeight - (2 * defaultTopAndBottomMargin)
        
        iconViewConstraints.append(contentsOf: [
            // Horizontal alignment
            iconImageView.centerXAnchor.constraint(
                equalTo: contentView.layoutMarginsGuide.leadingAnchor,
                constant: iconCenterFromLeadingMargin
            ),
            labelLabel.leadingAnchor.constraint(
                equalTo: iconImageView.centerXAnchor,
                constant: labelOffsetFromIconCenter
            ),
            
            // Vertical alignment
            iconImageView.centerYAnchor.constraint(equalTo: labelLabel.centerYAnchor),
        ])
        
        noIconViewConstraints.append(contentsOf: [
            labelLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
        ])
        
        NSLayoutConstraint.activate([
            // Horizontal alignment
            labelLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            
            // Vertical alignment
            labelLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: scaledTopAndBottomMargin),
            labelLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -scaledTopAndBottomMargin),
            
            // Height constraint
            labelLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: minLabelHeight),
        ])
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        action = nil
        iconImageView.image = nil
    }
    
    override func updateColors() {
        super.updateColors()
        
        if let isDestructive = action?.destructive, isDestructive {
            iconImageView.tintColor = Colors.red
            Colors.setTextColor(Colors.red, in: self)
        }
        else {
            iconImageView.tintColor = .primary
            // Button color is automatically set to `main()`
        }
    }
    
    private func updateIcon() {
        if iconImageView.image != nil {
            NSLayoutConstraint.deactivate(noIconViewConstraints)
            NSLayoutConstraint.activate(iconViewConstraints)
        }
        else {
            NSLayoutConstraint.deactivate(iconViewConstraints)
            NSLayoutConstraint.activate(noIconViewConstraints)
        }
    }
    
    private func updateTextAlignment() {
        if let isDestructive = action?.destructive, isDestructive,
           iconImageView.image == nil {
            // Center destructive actions without icon
            labelLabel.textAlignment = .center
        }
        else {
            labelLabel.textAlignment = .natural
        }
    }
    
    override func layoutMarginsDidChange() {
        super.layoutMarginsDidChange()
        
        // Adjust separator inset
        var leftSeparatorInset: CGFloat = 0
        if iconImageView.image != nil {
            leftSeparatorInset += iconCenterFromLeadingMargin + labelOffsetFromIconCenter
        }
        else if let isDestructive = action?.destructive, isDestructive {
            leftSeparatorInset = -layoutMargins.left
        }
        
        separatorInset = UIEdgeInsets(top: 0, left: leftSeparatorInset, bottom: 0, right: 0)
    }
}

// MARK: - Reusable

extension ActionDetailsTableViewCell: Reusable { }
