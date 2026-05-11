import Foundation
import UIKit

/// Subclass of UIImageView that should be used everywhere we show a profile picture.
public final class ProfilePictureImageView: UIView {
    
    public enum Info {
        case contact(Contact?)
        case edit(UIImage)
        case distributionList(DistributionList?)
        case group(Group?)
        case me
        case directoryContact(WorkAvailabilityStatus?)
    }
    
    public enum IconConfiguration {
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
                observeMyPicture()
                
            case .directoryContact:
                updateWorkAvailabilityIcon()
                setAndClip(image: ProfilePictureGenerator.directoryContactImage)
                
            case nil:
                profilePictureObserver?.invalidate()
                profilePictureObserver = nil
                imageView.image = nil
            }
            
            updateTypeIcon()
            updateWorkAvailabilityIcon()
        }
    }

    private var iconConfiguration: IconConfiguration
    private var profilePictureObserver: NSKeyValueObservation?
    private var myPictureObserver: NSObjectProtocol?
    private var workAvailabilityStatusObserver: NSKeyValueObservation?
    
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
    
    // Work Availability Status Icon
    // Note: Due to some weird issue when displaying the image view with a background in some cases, we have to add the
    // background as a separate view instead
    private lazy var workAvailabilityIconBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = .labelInverted
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    private lazy var workAvailabilityIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isHidden = true
        imageView.contentMode = .scaleAspectFit
        
        return imageView
    }()
    
    // MARK: - Lifecycle
    
    public init(iconConfiguration: IconConfiguration = .normal) {
        self.iconConfiguration = iconConfiguration
        super.init(frame: .zero)
        configureView()
    }
    
    override public init(frame: CGRect) {
        self.iconConfiguration = .normal
        super.init(frame: frame)
        configureView()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        self.iconConfiguration = .normal
        super.init(coder: coder)
        configureView()
    }
    
    deinit {
        profilePictureObserver?.invalidate()
        profilePictureObserver = nil
        if let myPictureObserver {
            NotificationCenter.default.removeObserver(myPictureObserver)
        }
        
        workAvailabilityStatusObserver?.invalidate()
        workAvailabilityStatusObserver = nil
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        clip()
    }
    
    // MARK: - Public functions
    
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
                multiplier: iconConfiguration.sizeMultiplier
            ),
            typeIconImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            typeIconImageView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        
        // Work availability icon background
        addSubview(workAvailabilityIconBackgroundView)
        NSLayoutConstraint.activate([
            workAvailabilityIconBackgroundView.widthAnchor.constraint(
                equalTo: widthAnchor,
                multiplier: iconConfiguration.sizeMultiplier
            ),
            workAvailabilityIconBackgroundView.heightAnchor.constraint(
                equalTo: workAvailabilityIconBackgroundView.widthAnchor
            ),
            workAvailabilityIconBackgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            workAvailabilityIconBackgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        
        // Work availability icon (on top of background)
        addSubview(workAvailabilityIconImageView)
        NSLayoutConstraint.activate([
            workAvailabilityIconImageView.centerXAnchor
                .constraint(equalTo: workAvailabilityIconBackgroundView.centerXAnchor),
            workAvailabilityIconImageView.centerYAnchor
                .constraint(equalTo: workAvailabilityIconBackgroundView.centerYAnchor),
            workAvailabilityIconImageView.widthAnchor.constraint(
                equalTo: workAvailabilityIconBackgroundView.widthAnchor,
                multiplier: 0.98
            ),
            workAvailabilityIconImageView.heightAnchor.constraint(
                equalTo: workAvailabilityIconImageView.widthAnchor
            ),
        ])
    }
    
    private func updateTypeIcon() {
        guard let info, iconConfiguration != .hidden else {
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
    
    private func updateWorkAvailabilityIcon() {
        guard let info, iconConfiguration != .hidden, ThreemaEnvironment.workAvailabilityStatusEnabled else {
            hideWorkAvailabilityIcon()
            return
        }
        
        if case let .contact(contact) = info {
            guard let contact, let status = contact.workAvailabilityStatus else {
                hideWorkAvailabilityIcon()
                return
            }
            
            workAvailabilityIconImageView.image = UIImage(systemName: status.category.systemImageName)?
                .withRenderingMode(.alwaysTemplate)
            workAvailabilityIconImageView.tintColor = status.category.color
            
            let shouldHide = status.category == .none
            workAvailabilityIconImageView.isHidden = shouldHide
            workAvailabilityIconBackgroundView.isHidden = shouldHide
        }
        else if case let .directoryContact(status) = info {
            guard let status else {
                hideWorkAvailabilityIcon()
                return
            }
            
            workAvailabilityIconImageView.image = UIImage(systemName: status.category.systemImageName)?
                .withRenderingMode(.alwaysTemplate)
            workAvailabilityIconImageView.tintColor = status.category.color
            
            let shouldHide = status.category == .none
            workAvailabilityIconImageView.isHidden = shouldHide
            workAvailabilityIconBackgroundView.isHidden = shouldHide
        }
        else {
            hideWorkAvailabilityIcon()
        }
    }
    
    private func hideWorkAvailabilityIcon() {
        workAvailabilityIconImageView.isHidden = true
        workAvailabilityIconBackgroundView.isHidden = true
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
        
        workAvailabilityStatusObserver = contact
            .observe(\.workAvailabilityStatus, options: [.initial]) { [weak self] _, _ in
                Task { @MainActor in
                    self?.updateWorkAvailabilityIcon()
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
    
    private func observeMyPicture() {
        profilePictureObserver?.invalidate()
        profilePictureObserver = nil
        
        updateMyPicture()
        
        if myPictureObserver == nil {
            myPictureObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name(rawValue: kNotificationProfilePictureChanged),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.updateMyPicture()
            }
        }
    }
    
    private func updateMyPicture() {
        let identityStore = MyIdentityStore.shared()
        
        if let pictureData = identityStore.profilePicture?["ProfilePicture"] as? Data,
           let picture = UIImage(data: pictureData) {
            setAndClip(image: picture)
            return
        }
        
        let color = identityStore.idColor
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
        
        // Make work availability icon background circular
        if workAvailabilityIconBackgroundView.bounds.height > 0 {
            workAvailabilityIconBackgroundView.layer.masksToBounds = true
            workAvailabilityIconBackgroundView.layer.cornerRadius = workAvailabilityIconBackgroundView.bounds.height / 2
        }
    }
}
