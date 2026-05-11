import CocoaLumberjackSwift
import Combine
import ThreemaMacros
import UIKit

/// Cell to represent any contact shown in a list
public final class ContactCell: ThemedCodeTableViewCell, Reusable {

    public enum Content {
        case me
        case contact(_: Contact)
        case unknownContact
    }

    // MARK: - Public properties
    
    override public func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        guard hasCheckmark else {
            return
        }
        checkMarkView.isChecked = selected
    }
    
    public var size = CellConfiguration.Size.small {
        didSet {
            guard size != oldValue else {
                return
            }
            
            configuration = CellConfiguration(size: size)
            sizeDidChange()
            updateContentForPreferredContentSizeCategory()
        }
    }
    
    public var hasCheckmark = false {
        didSet {
            checkMarkView.isHidden = !hasCheckmark
        }
    }
    
    /// Contact to show
    public var content: Content? {
        didSet {
            configureContent()
        }
    }

    /// Only use with Obj-C. It's here for backward compatibility and should be removed if no more Obj-C code uses this
    /// cell.
    /// Use `content` from Swift.
    @objc var _contactEntity: ContactEntity? {
        didSet {
            guard let contact = _contactEntity else {
                return
            }
            
            content = .contact(Contact(contactEntity: contact))
        }
    }

    // MARK: - Private properties

    private let businessInjector = BusinessInjector.ui
    private var anyCancellables: Set<AnyCancellable> = []
    private var contact: Contact?
    private var profilePictureSizeConstraint: NSLayoutConstraint!

    private lazy var configuration = CellConfiguration(size: size)
    private lazy var entityFetcher = entityManager.entityFetcher
    private lazy var entityManager = businessInjector.entityManager
    private lazy var settingsStore = businessInjector.settingsStore as? SettingsStore

    private lazy var profilePictureView: ProfilePictureImageView = {
        let imageView = ProfilePictureImageView()
        // Always use max height as possible and set the width with aspect ratio 1:1
        profilePictureSizeConstraint = imageView.heightAnchor
            .constraint(lessThanOrEqualToConstant: configuration.maxProfilePictureSize)
        profilePictureSizeConstraint.isActive = true
        return imageView
    }()
    
    private lazy var otherThreemaTypeIcon: UIView = {
        let icon = OtherThreemaTypeImageView()

        icon.translatesAutoresizingMaskIntoConstraints = false

        return icon
    }()

    private lazy var nameLabel: UILabel = {
        let label = UILabel()

        label.adjustsFontForContentSizeCategory = true
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        return label
    }()
    
    private lazy var verificationLevelImageView: UIImageView = {
        let imageView = UIImageView()
        
        imageView.contentMode = .scaleAspectFit
                
        return imageView
    }()
    
    private lazy var metadataLabel: UILabel = {
        let label = UILabel()

        label.adjustsFontForContentSizeCategory = true
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
    
    private lazy var checkMarkView: CustomCellCheckMarkAccessoryView = {
        let view = CustomCellCheckMarkAccessoryView()
        view.isHidden = !hasCheckmark

        return view
    }()
    
    private lazy var firstLineStack: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [nameLabel, verificationLevelImageView])
        
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 8
        stackView.distribution = .equalSpacing

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
        let stackView = UIStackView(arrangedSubviews: [profilePictureView, textStack, checkMarkView])
        
        stackView.axis = .horizontal
        stackView.distribution = .fill
        stackView.alignment = .center
        
        return stackView
    }()
    
    // MARK: - Super class overrides

    override public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        if let cancellable = settingsStore?.$blacklist.sink(
            receiveValue: { [weak self] _ in
                self?.configureContent()
            }
        ) {
            anyCancellables.insert(cancellable)
        }
    }

    override public func configureCell() {
        super.configureCell()
            
        sizeDidChange()
        updateContentForPreferredContentSizeCategory()

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

    // MARK: - Private methods

    private func configureMeCell() {
        let profile = ProfileStore().profile

        profilePictureView.info = .me
        otherThreemaTypeIcon.isHidden = true
        nameLabel.text = #localize("me")
        nameLabel.textColor = .label
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

    private func configureNameLabel(for contactEntity: ContactEntity) {
        func append(_ text: String, _ attrs: [NSAttributedString.Key: Any]) {
            result.append(NSAttributedString(string: text, attributes: attrs))
        }

        let isSortOrderFirstName = settingsStore?.sortOrderFirstName ?? false
        let isDisplayOrderFirstName = settingsStore?.displayOrderFirstName ?? true
        let isBlacklisted = settingsStore?.blacklist.contains(contactEntity.identity) ?? false

        let result = NSMutableAttributedString()

        let size = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .headline).pointSize
        let textColor: UIColor = contactEntity.isActive ? .label : .secondaryLabel

        var regular: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size),
            .foregroundColor: textColor,
        ]

        var bold: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .headline),
            .foregroundColor: textColor,
        ]

        if contactEntity.contactState == .invalid {
            regular[.strikethroughStyle] = NSUnderlineStyle.thick.rawValue
            bold[.strikethroughStyle] = NSUnderlineStyle.thick.rawValue
        }

        if isBlacklisted {
            append("🚫 ", regular)
        }

        let firstAttributes = isSortOrderFirstName ? bold : regular
        let lastAttributes = isSortOrderFirstName ? regular : bold

        var nameParts: [(String, [NSAttributedString.Key: Any])] = []

        if let first = contactEntity.firstName, !first.isEmpty {
            nameParts.append((first, firstAttributes))
        }

        if let last = contactEntity.lastName, !last.isEmpty {
            nameParts.append((last, lastAttributes))
        }

        if !isDisplayOrderFirstName {
            nameParts.reverse()
        }

        if !nameParts.isEmpty {
            for (index, part) in nameParts.enumerated() {
                if index > 0 {
                    append(" ", part.1)
                }
                append(part.0, part.1)
            }
        }
        else {
            if let publicNickname = contactEntity.publicNickname,
               !publicNickname.isEmpty,
               publicNickname != contactEntity.identity {
                append("~\(publicNickname)", bold)
            }
            else {
                append(contactEntity.identity, bold)
            }
        }

        nameLabel.attributedText = result
        let label = nameLabel.text ?? "" // Gets the plain string content. All attributes are ignored.

        var appendix =
            if isBlacklisted {
                #localize("blocked")
            }
            else if contactEntity.contactState != .active {
                #localize("inactive")
            }
            else {
                ""
            }
        
        if let status: WorkAvailabilityStatus = Contact(contactEntity: contactEntity).workAvailabilityStatus,
           let label = status.accessibilityLabelWithoutText {
            appendix += "\(label); "
        }
        
        nameLabel.accessibilityLabel = "\(label). \(appendix)"
    }

    private func configureContactCell(for contact: Contact) {
        self.contact = contact

        entityManager.performAndWait {
            if let contactEntity = self.entityFetcher.contactEntity(for: contact.identity.rawValue) {
                self.profilePictureView.info = .contact(contact)
                self.configureNameLabel(for: contactEntity)
                self.otherThreemaTypeIcon.isHidden = !contactEntity.showOtherThreemaTypeIcon
            }
            else {
                DDLogError(
                    "Can't find contact entity to set the profile picture, type icon and name. It will show 'me' as contact name"
                )
                self.otherThreemaTypeIcon.isHidden = true
                self.configureMeCell()
            }
        }

        verificationLevelImageView.accessibilityLabel = contact.verificationLevelAccessibilityLabel
        
        var nickname = ""
        if let publicNickname = contact.publicNickname,
           publicNickname != contact.identity.rawValue {
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
                    contact.identity.rawValue
                }
        }
        else {
            metadataLabel.text = nickname
            identityLabel.text = contact.identity.rawValue
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

    private func configureContent() {
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

        updateContentForPreferredContentSizeCategory()
    }

    private func sizeDidChange() {
        nameLabel.font = configuration.nameLabelFont
        containerStack.spacing = configuration.horizontalSpacing
        
        // Note: We don't reload the profile picture here. So if the `content` is assigned before the `size`
        // we might have a blurry profile picture.
        profilePictureSizeConstraint.constant = configuration.maxProfilePictureSize
    }

    private func updateContentForPreferredContentSizeCategory() {
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            nameLabel.numberOfLines = 3
            profilePictureView.isHidden = true

            firstLineStack.axis = .vertical
            firstLineStack.alignment = .leading
            firstLineStack.removeArrangedSubview(verificationLevelImageView)
            firstLineStack.addArrangedSubview(accessibilityContentSizeStack)

            secondLineStack.axis = .vertical
            secondLineStack.alignment = .leading

            otherThreemaTypeIcon.widthAnchor.constraint(equalToConstant: 20).isActive = true

            contact.map { verificationLevelImageView.image = $0.verificationLevelImage }

            separatorInset = UIEdgeInsets(
                top: 0,
                left: configuration.maxProfilePictureSize + configuration.horizontalSpacing,
                bottom: 0,
                right: 0
            )
        }
        else {
            nameLabel.numberOfLines = 1
            profilePictureView.isHidden = false

            firstLineStack.axis = .horizontal
            firstLineStack.alignment = .center
            firstLineStack.removeArrangedSubview(accessibilityContentSizeStack)
            firstLineStack.addArrangedSubview(verificationLevelImageView)

            secondLineStack.axis = .horizontal
            secondLineStack.alignment = .firstBaseline

            for constraint in otherThreemaTypeIcon.constraints where constraint.firstAttribute == .width {
                constraint.isActive = false
            }

            contact.map { verificationLevelImageView.image = $0.verificationLevelImageSmall }

            separatorInset = .zero
        }
    }
}
