import ThreemaMacros

public final class RecipientCollectionCountLabel: UILabel {

    // MARK: - Kind
    
    public enum Kind {
        case group
        case distributionList
        case profilePicture
        case none
    }
    
    // MARK: - Constants

    private enum Constants {
        static let maxGroupMembers = Group.maxGroupMembers
    }

    // MARK: - Lifecycle

    override public init(frame: CGRect) {
        super.init(frame: frame)

        font = .preferredFont(forTextStyle: .headline)
        textColor = .secondaryLabel
        adjustsFontForContentSizeCategory = true
        numberOfLines = 1
        setContentCompressionResistancePriority(.required, for: .vertical)
        setContentHuggingPriority(.required, for: .vertical)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configure

    public func configure(for kind: Kind, count: Int) {
        let format: String =
            switch kind {
            case .group:
                #localize("invite_group_count")
            case .distributionList:
                #localize("invite_distribution_list_count")
            case .profilePicture:
                #localize("send_profileimage_contacts")
            case .none:
                ""
            }
        
        text = String(format: format, "\(count)", "\(Constants.maxGroupMembers)")
    }
}

#if DEBUG
    #Preview {
        let group = RecipientCollectionCountLabel()
        group.configure(for: .group, count: 10)

        let distributionList = RecipientCollectionCountLabel()
        distributionList.configure(for: .distributionList, count: 10)

        let profilePicture = RecipientCollectionCountLabel()
        profilePicture.configure(for: .profilePicture, count: 10)

        let vStack = UIStackView(arrangedSubviews: [
            group,
            distributionList,
            profilePicture,
        ])
        vStack.axis = .vertical
        vStack.spacing = 16

        return vStack
    }

#endif
