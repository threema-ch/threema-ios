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

import ThreemaMacros

// MARK: - SelectContactListHeaderViewDelegate

protocol SelectContactListHeaderViewDelegate: AnyObject {
    func header(_ header: SelectContactListHeaderView, itemForIndexPath indexPath: IndexPath)
        -> Contact
}

final class SelectContactListHeaderView: UIView {
    
    // MARK: - Type
    
    private enum HeaderSection {
        case main
    }
    
    // MARK: - Public properties
    
    weak var delegate: (SelectContactListViewController & ContactSelectionHandler)? {
        didSet {
            collectionViewFlow.delegate = delegate
        }
    }
    
    // MARK: - Private properties

    private lazy var dataSource = UICollectionViewDiffableDataSource<
        HeaderSection,
        Contact
    >(collectionView: collectionView) { [weak self] collectionView, indexPath, _ in
        guard let self,
              let cell = collectionView.dequeueReusableCell(
                  withReuseIdentifier: ContactGridContactCell.reuseIdentifier,
                  for: indexPath
              ) as? ContactGridContactCell,
              let item = delegate?.header(self, itemForIndexPath: indexPath) else {
            return UICollectionViewCell()
        }
        
        cell.configure(for: item)
        cell.onClear = { [weak self] in
            guard let self else {
                return
            }
            
            delegate?.didDeselect(item: item)
        }
        return cell
    }

    private lazy var collectionViewFlow = SelectContactListHeaderViewLayout()
    private lazy var countLabel = ContactCollectionCountLabel()
    private lazy var collectionView = {
        let collection = UICollectionView(frame: .zero, collectionViewLayout: collectionViewFlow)
        collection.showsHorizontalScrollIndicator = true
        collection.backgroundColor = .clear
        collection.register(
            ContactGridContactCell.self,
            forCellWithReuseIdentifier: ContactGridContactCell.reuseIdentifier
        )
        collection.isHidden = true
        
        collectionViewFlow.reportSizeChange = { [weak self] in
            self?.updateSizeIfNeeded()
        }
        
        return collection
    }()

    private lazy var stackView = {
        let labelContainer = UIView()
        labelContainer.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 0,
            leading: 16,
            bottom: 0,
            trailing: 16
        )
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
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 8,
            leading: 0,
            bottom: 8,
            trailing: 0
        )
        return stack
    }()

    private lazy var collectionHeightConstraint = collectionView.heightAnchor.constraint(equalToConstant: 0)
    private let collectionKind: ContactCollectionCountLabel.Kind

    // MARK: - Lifecycle

    init(collectionKind: ContactCollectionCountLabel.Kind) {
        self.collectionKind = collectionKind
        super.init(frame: .zero)
        
        updateLabel()
        
        backgroundColor = .systemGroupedBackground
        addSubview(stackView)
        
        directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 0,
            leading: 20,
            bottom: 0,
            trailing: 20
        )
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
        
        collectionHeightConstraint.isActive = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Configuration

    func configure() {
        guard let items = delegate?.selectedItems() else {
            return
        }
        
        updateLabel()
        
        var snapshot = NSDiffableDataSourceSnapshot<HeaderSection, Contact>()
        snapshot.appendSections([.main])
        snapshot.appendItems(items, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: true)
        
        if items.isEmpty {
            isHidden = true
        }
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

    func contentSizeCategoryDidChange() {
        collectionView.collectionViewLayout.invalidateLayout()
        updateSizeIfNeeded()
    }
}
