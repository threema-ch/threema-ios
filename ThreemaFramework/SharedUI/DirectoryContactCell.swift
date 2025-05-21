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

import CocoaLumberjackSwift
import ThreemaMacros
import UIKit

/// Cell to represent any contact shown in a list
public final class DirectoryContactCell: ThemedCodeTableViewCell {
    
    // MARK: - Private configuration
    
    private lazy var configuration = CellConfiguration(size: size)
    
    // MARK: - Public properties
    
    public var size = CellConfiguration.Size.small {
        didSet {
            guard size != oldValue else {
                return
            }
            
            configuration = CellConfiguration(size: size)
            sizeDidChange()
        }
    }
    
    /// Contact to show
    public var directoryContact: CompanyDirectoryContact? {
        didSet {
            guard let directoryContact else {
                return
            }

            configureCell(for: directoryContact)
        }
    }
    
    // MARK: - Subviews
    
    private var profilePictureSizeConstraint: NSLayoutConstraint?
    
    private lazy var profilePictureView: ProfilePictureImageView = {
        let imageView = ProfilePictureImageView()
        // Always use max height as possible and set the width with aspect ratio 1:1
        profilePictureSizeConstraint = imageView.heightAnchor
            .constraint(lessThanOrEqualToConstant: configuration.maxProfilePictureSize)
        profilePictureSizeConstraint?.isActive = true
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            imageView.isHidden = true
        }
        
        return imageView
    }()
    
    private lazy var nameLabel: ContactNameLabel = {
        let label = ContactNameLabel()
            
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            label.numberOfLines = 2
        }
        
        return label
    }()
    
    private lazy var metadataLabel: UILabel = {
        let label = UILabel()
        
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        return label
    }()
    
    private lazy var identityLabel: UILabel = {
        let label = UILabel()
        
        label.textAlignment = .right
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        
        return label
    }()
    
    // MARK: Layout stacks
    
    private lazy var firstLineStack: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [nameLabel])
        
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 8
        stackView.distribution = .equalSpacing
        
        // As view cells are recreated for each content size change we can just set it here
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            stackView.axis = .vertical
            stackView.alignment = .leading
        }
        
        return stackView
    }()
    
    private lazy var secondLineStack: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [metadataLabel, identityLabel])
        
        stackView.axis = .horizontal
        stackView.alignment = .firstBaseline
        stackView.spacing = 8
        stackView.distribution = .equalSpacing
        
        // As view cells are recreated for each content size change we can just set it here
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            stackView.axis = .vertical
            stackView.alignment = .leading
        }
        
        return stackView
    }()
    
    private lazy var textStack: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [firstLineStack, secondLineStack])

        stackView.spacing = configuration.verticalSpacing
        stackView.axis = .vertical
        stackView.distribution = .equalSpacing
        stackView.alignment = .fill

        return stackView
    }()
    
    private lazy var containerStack: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [profilePictureView, textStack])
        
        stackView.axis = .horizontal
        stackView.distribution = .fill
        stackView.alignment = .center
        
        return stackView
    }()
    
    // MARK: - Lifecycle
    
    override public func configureCell() {
        super.configureCell()
            
        sizeDidChange()
        
        // Container configuration
        contentView.addSubview(containerStack)
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            containerStack.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            containerStack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            containerStack.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
            containerStack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            identityLabel.widthAnchor.constraint(lessThanOrEqualTo: secondLineStack.widthAnchor, multiplier: 0.6),
            identityLabel.widthAnchor.constraint(greaterThanOrEqualTo: secondLineStack.widthAnchor, multiplier: 0.2),
        ])
    }
    
    // MARK: - Reuse configuration
    
    private func configureCell(for contact: CompanyDirectoryContact) {
        profilePictureView.info = .directoryContact
        
        nameLabel.text = contact.fullName()
        
        if let jobTitle = contact.jobTitle, jobTitle != "" {
            metadataLabel.text = jobTitle
        }
        else {
            metadataLabel.text = contact.id
        }
        identityLabel.text = contact.department ?? ""
    }
    
    // MARK: - Updates
    
    private func sizeDidChange() {
        nameLabel.font = configuration.nameLabelFont
        containerStack.spacing = configuration.horizontalSpacing
        
        // Note: We don't reload the profile picture here. So if the `content` is assigned before the `size`
        // we might have a blurry profile picture.
        profilePictureSizeConstraint?.constant = configuration.maxProfilePictureSize
        
        updateSeparatorInset()
    }
    
    private func updateSeparatorInset() {
        guard !traitCollection.preferredContentSizeCategory.isAccessibilityCategory else {
            separatorInset = .zero
            return
        }
        
        let leftSeparatorInset = configuration.maxProfilePictureSize + configuration.horizontalSpacing
        separatorInset = UIEdgeInsets(top: 0, left: leftSeparatorInset, bottom: 0, right: 0)
    }
    
    // MARK: - Accessibility
    
    override public var accessibilityLabel: String? {
        get {
            nameLabel.accessibilityLabel
        }
        set { }
    }
    
    override public var accessibilityValue: String? {
        get {
            [
                metadataLabel.text,
                identityLabel.text,
            ]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ". ")
        }
        set { }
    }
}

// MARK: - Reusable

extension DirectoryContactCell: Reusable { }
