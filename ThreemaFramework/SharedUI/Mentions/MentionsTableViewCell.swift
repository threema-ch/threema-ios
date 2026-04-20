import Foundation
import ThreemaMacros

final class MentionsTableViewCell: ThemedCodeTableViewCell {
    // MARK: Subviews
    
    public lazy var profilePictureView: ProfilePictureImageView = {
        let profilePictureView = ProfilePictureImageView()
        profilePictureView.translatesAutoresizingMaskIntoConstraints = false
        profilePictureView.heightAnchor.constraint(lessThanOrEqualToConstant: 35).isActive = true
        profilePictureView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        if #available(iOS 26.0, *) {
            profilePictureView.addBackground()
        }
        
        return profilePictureView
    }()
    
    public lazy var nameLabel: UILabel = {
        let label = UILabel()
        
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = .label
        
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
        
        if #available(iOS 26.0, *) {
            backgroundColor = nil
        }
        else {
            backgroundColor = .secondarySystemBackground
        }
        
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
}

// MARK: - Reusable

extension MentionsTableViewCell: Reusable { }
