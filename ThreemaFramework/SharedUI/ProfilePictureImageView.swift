//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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
import UIKit

/// Subclass of UIImageView that should be used everywhere we show a profile picture.
@objc public class ProfilePictureImageView: UIView {
    
    public enum Info {
        case contact(Contact?)
        case edit(UIImage)
        case distributionList(DistributionList?)
        case group(Group?)
        case me
    }
    
    public enum TypeIconConfiguration {
        case hidden
        case small
        case normal
        
        var sizeMultiplier: CGFloat {
            switch self {
            case .hidden:
                0.0
            case .small:
                0.25
            case .normal:
                0.35
            }
        }
    }
    
    public var info: Info? {
        didSet {
            switch info {
            case let .contact(contact):
                observe(contact)
                
            case let .distributionList(distributionList):
                observe(distributionList)
                
            case let .edit(image):
                setEditImage(image)
                
            case let .group(group):
                observe(group)
                
            case .me:
                setMyPicture()
                
            case nil:
                profilePictureObserver?.invalidate()
                profilePictureObserver = nil
                imageView.image = nil
            }
            
            updateTypeIcon()
        }
    }

    private var typeIconConfiguration: TypeIconConfiguration
    private var profilePictureObserver: NSKeyValueObservation?
    
    // MARK: - Overrides
    
    override public var bounds: CGRect {
        didSet {
            clip()
        }
    }
    
    // MARK: - Subviews
    
    private lazy var imageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentMode = .scaleAspectFill
        accessibilityIgnoresInvertColors = true
        
        return imageView
    }()

    // We need this to be public to show a tip in single details
    public private(set) lazy var typeIconImageView: UIImageView = {
        let imageView = OtherThreemaTypeImageView()
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isHidden = true
        
        return imageView
    }()
    
    // MARK: - Lifecycle
    
    public init(typeIconConfiguration: TypeIconConfiguration = .normal) {
        self.typeIconConfiguration = typeIconConfiguration
        super.init(frame: .zero)
        configureView()
    }
    
    override public init(frame: CGRect) {
        self.typeIconConfiguration = .normal
        super.init(frame: frame)
        configureView()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        self.typeIconConfiguration = .normal
        super.init(coder: coder)
        configureView()
    }
    
    deinit {
        profilePictureObserver?.invalidate()
        profilePictureObserver = nil
    }
    
    @objc public func setContact(contact: Contact) {
        info = .contact(contact)
    }
    
    @objc public func setMe() {
        info = .me
    }
    
    @objc public func setChosenImage(_ image: UIImage) {
        info = .edit(image)
    }
    
    /// Adds a background to remove the opacity
    /// Note: Since we do not observe wallpaper changes for now, we go not need a remove function.
    public func addBackground() {
        imageView.backgroundColor = .white.withAlphaComponent(0.8)
    }
    
    // MARK: - Private functions

    private func configureView() {
        setContentHuggingPriority(.defaultHigh, for: .horizontal)
        widthAnchor.constraint(equalTo: heightAnchor).isActive = true
        
        // Profile picture
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        
        // Type icon
        addSubview(typeIconImageView)
        NSLayoutConstraint.activate([
            typeIconImageView.widthAnchor.constraint(
                equalTo: widthAnchor,
                multiplier: typeIconConfiguration.sizeMultiplier
            ),
            typeIconImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            typeIconImageView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
    
    private func updateTypeIcon() {
        guard let info, typeIconConfiguration != .hidden else {
            typeIconImageView.isHidden = true
            return
        }
        
        if case let .contact(contact) = info {
            guard let contact else {
                typeIconImageView.isHidden = true
                return
            }
            typeIconImageView.isHidden = !contact.showOtherTypeIcon
        }
        else {
            typeIconImageView.isHidden = true
        }
    }
    
    private func observe(_ contact: Contact?) {
        profilePictureObserver?.invalidate()
        
        guard let contact else {
            profilePictureObserver = nil
            setAndClip(image: ProfilePictureGenerator.unknownContactImage)
            return
        }
        
        profilePictureObserver = contact.observe(\.profilePicture, options: [.initial]) { [weak self] _, _ in
            Task { @MainActor in
                self?.setAndClip(image: contact.profilePicture)
            }
        }
    }
    
    private func observe(_ group: Group?) {
        profilePictureObserver?.invalidate()
        
        guard let group else {
            profilePictureObserver = nil
            setAndClip(image: ProfilePictureGenerator.unknownGroupImage)
            return
        }
        
        profilePictureObserver = group.observe(\.profilePicture, options: [.initial]) { [weak self] _, _ in
            Task { @MainActor in
                self?.setAndClip(image: group.profilePicture)
            }
        }
    }
    
    private func observe(_ distributionList: DistributionList?) {
        profilePictureObserver?.invalidate()
        
        guard let distributionList else {
            profilePictureObserver = nil
            setAndClip(image: ProfilePictureGenerator.unknownDistributionListImage)
            return
        }
        
        profilePictureObserver = distributionList.observe(\.profilePicture, options: [.initial]) { [weak self] _, _ in
            self?.setAndClip(image: distributionList.profilePicture)
        }
    }
    
    private func setMyPicture() {
        profilePictureObserver?.invalidate()
        profilePictureObserver = nil
        
        let identityStore = MyIdentityStore.shared()
        
        if let pictureData = identityStore?.profilePicture?["ProfilePicture"] as? Data,
           let picture = UIImage(data: pictureData) {
            setAndClip(image: picture)
            return
        }
        
        let color = identityStore?.idColor ?? .primary
        setAndClip(image: ProfilePictureGenerator.generateImage(for: .me, color: color))
    }
    
    private func setEditImage(_ image: UIImage) {
        setAndClip(image: image)
    }
    
    private func setAndClip(image: UIImage?) {
        Task { @MainActor in
            self.imageView.image = image
            self.clip()
        }
    }
    
    private func clip() {
        imageView.layer.masksToBounds = true
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = frame.height / 2
    }
}
