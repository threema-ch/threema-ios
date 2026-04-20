import ThreemaMacros

final class ContactGridHeaderView: UICollectionReusableView {
    
    // MARK: - Constants

    private enum Constants {
        static let horizontalInset: CGFloat = 0
        static let verticalInset: CGFloat = 8
    }
    
    // MARK: - Subviews

    private lazy var countLabel = RecipientCollectionCountLabel()

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(countLabel)
        backgroundColor = .clear
        
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            countLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Constants.horizontalInset),
            countLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Constants.horizontalInset),
            countLabel.topAnchor.constraint(equalTo: topAnchor, constant: Constants.verticalInset),
            countLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Constants.verticalInset),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configuration

    func configure(for kind: RecipientCollectionCountLabel.Kind, with count: Int) {
        countLabel.configure(for: kind, count: count)
    }
}

// MARK: - Reusable

extension ContactGridHeaderView: Reusable { }
