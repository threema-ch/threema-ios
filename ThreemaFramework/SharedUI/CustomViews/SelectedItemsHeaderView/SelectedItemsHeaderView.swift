import ThreemaMacros

public final class SelectedItemsHeaderView: UIView {

    // MARK: - Type
    
    private enum HeaderSection: Hashable {
        case main
    }
    
    // MARK: - Public properties
    
    public weak var delegate: (SelectedItemsHeaderViewDelegate & ItemSelectionHandler)? {
        didSet {
            collectionViewFlow.delegate = delegate
        }
    }
    
    // MARK: - Private properties

    private lazy var dataSource = UICollectionViewDiffableDataSource<
        HeaderSection,
        ItemID
    >(collectionView: collectionView) { [weak self] collectionView, indexPath, _ in
        guard
            let self,
            let item = delegate?.header(self, itemForIndexPath: indexPath)
        else {
            return nil
        }
        let cell: SelectedItemGridCell = collectionView.dequeueCell(for: indexPath)
        cell.configure(for: item)
        cell.onClear = { [weak self] in
            self?.delegate?.didDeselect(id: item.id)
        }
        return cell
    }

    private lazy var collectionViewFlow = SelectedItemsHeaderViewLayout()
    private lazy var countLabel = RecipientCollectionCountLabel()
    private lazy var collectionView = {
        let collection = UICollectionView(frame: .zero, collectionViewLayout: collectionViewFlow)
        collection.showsHorizontalScrollIndicator = true
        collection.backgroundColor = .clear
        collection.registerCell(SelectedItemGridCell.self)
        collection.isHidden = true
        
        collectionViewFlow.reportSizeChange = { [weak self] in
            self?.updateSizeIfNeeded()
        }
        
        return collection
    }()

    private lazy var stackView = {
        let labelContainer = UIView()
        labelContainer.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        labelContainer.addSubview(countLabel)
        
        countLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            countLabel.topAnchor.constraint(equalTo: labelContainer.topAnchor),
            countLabel.leadingAnchor.constraint(equalTo: labelContainer.layoutMarginsGuide.leadingAnchor),
            countLabel.trailingAnchor.constraint(equalTo: labelContainer.layoutMarginsGuide.trailingAnchor),
            countLabel.bottomAnchor.constraint(equalTo: labelContainer.bottomAnchor),
        ])
        
        let stack = UIStackView(arrangedSubviews: [labelContainer, collectionView])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 8
        stack.backgroundColor = .secondarySystemGroupedBackground
        stack.layer.cornerRadius = 10
        stack.layer.masksToBounds = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
        return stack
    }()

    private lazy var collectionHeightConstraint = collectionView.heightAnchor.constraint(equalToConstant: 0)
    private let collectionKind: RecipientCollectionCountLabel.Kind

    // MARK: - Lifecycle

    public init(collectionKind: RecipientCollectionCountLabel.Kind) {
        self.collectionKind = collectionKind
        super.init(frame: .zero)
        
        updateLabel()
        
        backgroundColor = .systemGroupedBackground
        addSubview(stackView)

        directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
        
        collectionHeightConstraint.isActive = true
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Configuration

    public func configure() {
        guard let itemIDs = delegate?.selectedItems().map(\.id) else {
            return
        }

        updateLabel()
        
        var snapshot = NSDiffableDataSourceSnapshot<HeaderSection, ItemID>()
        snapshot.appendSections([.main])
        snapshot.appendItems(itemIDs, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: true)
        isHidden = itemIDs.isEmpty
    }
    
    private func updateSizeIfNeeded() {
        let collectionHeight = collectionView.collectionViewLayout.collectionViewContentSize.height
        let oldHeight = collectionHeightConstraint.constant
        
        guard oldHeight != collectionHeight else {
            return
        }
        
        collectionHeightConstraint.constant = collectionHeight

        if collectionHeight == 0 {
            collectionView.isHidden = true
        }
        else if oldHeight == 0 {
            collectionView.isHidden = false
        }
        
        UIView.animate(withDuration: 0.25) { [weak self] in
            self?.superview?.layoutIfNeeded()
        }
    }
    
    private func updateLabel() {
        let count = delegate?.selectedItems().count ?? 0
        countLabel.configure(for: collectionKind, count: count)
    }
    
    // MARK: - Notification

    public func invalidateLayout() {
        collectionView.collectionViewLayout.invalidateLayout()
        updateSizeIfNeeded()
    }
}
