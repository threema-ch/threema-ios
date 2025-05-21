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

import CocoaLumberjackSwift
import ThreemaMacros
import UIKit

/// Cell to represent any contact shown in a list
public final class ContactCell: ThemedCodeTableViewCell {
    
    public enum Content {
        case me
        case contact(_: Contact)
        case unknownContact
    }
    
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
    public var content: Content? {
        didSet {
            guard let content else {
                return
            }
            
            switch content {
            case .me:
                configureMeCell()
            case let .contact(contact):
                configureContactCell(for: contact)
            case .unknownContact:
                configureUnknownContactCell()
            }
        }
    }
    
    /// Only use with Obj-C. It's here for backward compatibility and should be removed if no more Obj-C code uses this
    /// cell.
    /// Use `content` from Swift.
    @objc var _contact: ContactEntity? {
        didSet {
            guard let contact = _contact else {
                return
            }
            
            content = .contact(Contact(contactEntity: contact))
        }
    }
    
    // MARK: - Subviews
    
    private var profilePictureSizeConstraint: NSLayoutConstraint!
    
    private lazy var profilePictureView: ProfilePictureImageView = {
        let imageView = ProfilePictureImageView()
        // Always use max height as possible and set the width with aspect ratio 1:1
        profilePictureSizeConstraint = imageView.heightAnchor
            .constraint(lessThanOrEqualToConstant: configuration.maxProfilePictureSize)
        profilePictureSizeConstraint.isActive = true
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            imageView.isHidden = true
        }
        
        return imageView
    }()
    
    private lazy var otherThreemaTypeIcon = OtherThreemaTypeImageView()
    
    private lazy var nameLabel: ContactNameLabel = {
        let label = ContactNameLabel()
            
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            label.numberOfLines = 2
        }
        
        return label
    }()
    
    private lazy var verificationLevelImageView: UIImageView = {
        let imageView = UIImageView()
        
        imageView.contentMode = .scaleAspectFit
                
        return imageView
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
        let stackView = UIStackView(arrangedSubviews: [nameLabel, verificationLevelImageView])
        
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 8
        stackView.distribution = .equalSpacing
        
        // As view cells are recreated for each content size change we can just set it here
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            stackView.axis = .vertical
            stackView.alignment = .leading
            
            // Replace verification level by verification level and type icon stack
            stackView.removeArrangedSubview(verificationLevelImageView)
            stackView.addArrangedSubview(accessibilityContentSizeStack)
        }
        
        return stackView
    }()
    
    private lazy var accessibilityContentSizeStack: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [verificationLevelImageView, otherThreemaTypeIcon])
        
        stackView.spacing = 8
        stackView.axis = .horizontal
        stackView.alignment = .center
        
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
        
        // Type icon configuration
        
        otherThreemaTypeIcon.translatesAutoresizingMaskIntoConstraints = false
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            // Approximation for a similar size to verification level image
            // Setting the size to the size of the verification level image view didn't work.
            otherThreemaTypeIcon.widthAnchor.constraint(equalToConstant: 20).isActive = true
        }
        else {
            otherThreemaTypeIcon.isHidden = true
        }
        
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
    
    private func configureMeCell() {
        let profile = ProfileStore().profile()
        
        profilePictureView.info = .me
        otherThreemaTypeIcon.isHidden = true
        nameLabel.contact = nil // #localize("me")
        verificationLevelImageView.image = nil
        verificationLevelImageView.accessibilityLabel = nil
        
        metadataLabel.text = profile.nickname
        identityLabel.text = nil
        
        containerStack.alpha = 1
        
        if size == .medium {
            accessoryType = .none
            selectionStyle = .none
            contentView.alpha = 1
        }
    }
    
    private func configureContactCell(for contact: Contact) {
        let em = BusinessInjector().entityManager
        em.performBlock {
            if let contactEntity = em.entityFetcher.contact(for: contact.identity.string) {
                self.profilePictureView.info = .contact(contact)
                self.nameLabel.contact = contactEntity
                self.otherThreemaTypeIcon.isHidden = !contactEntity.showOtherThreemaTypeIcon
            }
            else {
                DDLogError(
                    "Can't find contact entity to set the profile picture, type icon and name. It will show 'me' as contact name"
                )
                self.otherThreemaTypeIcon.isHidden = true
                self.nameLabel.contact = nil
            }
        }

        verificationLevelImageView.image = contact.verificationLevelImageSmall
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            verificationLevelImageView.image = contact.verificationLevelImage
        }
        verificationLevelImageView.accessibilityLabel = contact.verificationLevelAccessibilityLabel
        
        var nickname = ""
        if let publicNickname = contact.publicNickname,
           publicNickname != contact.identity.string {
            nickname = "~\(publicNickname)"
        }
        
        if TargetManager.isBusinessApp {
            metadataLabel.text =
                if let jobTitle = contact.jobTitle,
                !jobTitle.isEmpty {
                    jobTitle
                }
                else {
                    nickname
                }
            
            identityLabel.text =
                if let department = contact.department,
                !department.isEmpty {
                    department
                }
                else {
                    contact.identity.string
                }
        }
        else {
            metadataLabel.text = nickname
            identityLabel.text = contact.identity.string
        }
        
        if contact.isActive {
            containerStack.alpha = 1
        }
        else {
            containerStack.alpha = 0.5
        }
        
        if size == .medium {
            accessoryType = .disclosureIndicator
            selectionStyle = .default
            contentView.alpha = 1
        }
    }
    
    private func configureUnknownContactCell() {
        
        profilePictureView.info = .contact(nil)
        
        otherThreemaTypeIcon.isHidden = true
        
        nameLabel.text = #localize("(unknown)")
        
        verificationLevelImageView.image = nil
        verificationLevelImageView.accessibilityLabel = nil
        
        metadataLabel.text = nil
        identityLabel.text = nil
        
        containerStack.alpha = 0.5
        
        if size == .medium {
            accessoryType = .none
            selectionStyle = .none
            contentView.alpha = 1
        }
    }
    
    // MARK: - Updates
    
    private func sizeDidChange() {
        nameLabel.font = configuration.nameLabelFont
        containerStack.spacing = configuration.horizontalSpacing
        
        // Note: We don't reload the profile picture here. So if the `content` is assigned before the `size`
        // we might have a blurry profile picture.
        profilePictureSizeConstraint.constant = configuration.maxProfilePictureSize
        
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
            var otherThreemaTypeIconAccessibilityLabel: String?
            if !otherThreemaTypeIcon.isHidden {
                otherThreemaTypeIconAccessibilityLabel = otherThreemaTypeIcon.accessibilityLabel
            }
            
            return [
                metadataLabel.text,
                identityLabel.text,
                otherThreemaTypeIconAccessibilityLabel,
                verificationLevelImageView.accessibilityLabel,
            ]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ". ")
        }
        set { }
    }
}

// MARK: - Reusable

extension ContactCell: Reusable { }
