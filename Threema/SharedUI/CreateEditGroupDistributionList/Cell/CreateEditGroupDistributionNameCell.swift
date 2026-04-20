final class CreateEditGroupDistributionNameCell: UICollectionViewCell {
    
    // MARK: - Public properties
    
    var nameType: EditNameInputView.NameType {
        get { nameInputView.nameType }
        set { nameInputView.nameType = newValue }
    }
    
    var name: String? {
        get { nameInputView.name }
        set { nameInputView.name = newValue }
    }
    
    var onTextChanged: ((String?) -> Void)?
    
    // MARK: - Private properties
    
    private lazy var nameInputView = EditNameInputView()
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        contentView.addSubview(nameInputView)
        contentView.backgroundColor = .secondarySystemGroupedBackground
        contentView.layer.cornerRadius = 10
        contentView.layer.masksToBounds = true
        
        nameInputView.translatesAutoresizingMaskIntoConstraints = false
        nameInputView.backgroundColor = .clear
        
        NSLayoutConstraint.activate([
            nameInputView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 4),
            nameInputView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor, constant: 4),
            nameInputView.trailingAnchor.constraint(
                equalTo: contentView.layoutMarginsGuide.trailingAnchor,
                constant: -4
            ),
            nameInputView.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor, constant: -4),
        ])
        
        nameInputView.onTextChanged = { [weak self] text in
            self?.onTextChanged?(text)
        }
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        onTextChanged = nil
    }
}

// MARK: - Reusable

extension CreateEditGroupDistributionNameCell: Reusable { }
