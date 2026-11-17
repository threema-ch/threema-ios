import CocoaLumberjackSwift
import Foundation
import ThreemaMacros

/// `UICollectionView` grid showing media, i.e. photos, videos and GIFs
final class MediaBrowserGridCollectionView: UICollectionView, UICollectionViewDelegate {
    
    // MARK: - Layout
    
    private enum Mode {
        case `default`
        case multiselect
    }
    
    static var layout: UICollectionViewCompositionalLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1 / 3),
            heightDimension: .fractionalWidth(1 / 3)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0.5, leading: 0.5, bottom: 0.5, trailing: 0.5)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .fractionalWidth(1 / 3)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)

        // Month of the section, stays visible at the top while scrolling through it
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(40)),
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        header.pinToVisibleBounds = true
        header.zIndex = 1
        section.boundarySupplementaryItems = [header]

        // Number of media below the last section
        let footer = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(50)),
            elementKind: UICollectionView.elementKindSectionFooter,
            alignment: .bottom
        )
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.boundarySupplementaryItems = [footer]

        return UICollectionViewCompositionalLayout(section: section, configuration: configuration)
    }

    // MARK: - Public properties
    
    var allSelected: Bool {
        selectedItems.count == mediaManager.allObjectIDs.count
    }

    var selectedCount: Int {
        selectedItems.count
    }
    
    var totalCount: Int {
        mediaManager.allObjectIDs.count
    }
    
    var selectedObjectIDs: [NSManagedObjectID] {
        Array(selectedItems)
    }
    
    // MARK: - Private properties

    private let mediaManager: MediaBrowserMediaManager
    private weak var tapDelegate: (any MediaBrowserTapDelegate)?
    
    private var mode: Mode = .default
    private var selectedItems = Set<NSManagedObjectID>()
    
    private lazy var gridDataSource: MediaBrowserGridCollectionViewDataSource = MediaBrowserGridCollectionViewDataSource(
        mediaManager: mediaManager,
        collectionView: self,
        cellProvider: cellProvider
    )
    
    private lazy var cellProvider: MediaBrowserGridCollectionViewDataSource.CellProvider = { [weak self] collectionView, indexPath, itemIdentifier in
        
        guard let self else {
            return nil
        }
        
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: MediaBrowserGridCollectionViewCell.reuseIdentifier,
            for: indexPath
        ) as? MediaBrowserGridCollectionViewCell else {
            return nil
        }
        
        let thumbnailDisplayMessage = mediaManager.thumbnailDisplayMessage(for: itemIdentifier)
        
        cell.thumbnailDisplayMessage = thumbnailDisplayMessage
        
        // Make sure dequeued cells have correct edit / select state
        cell.isMultiselecting = mode == .multiselect
        cell.isMultiselected = selectedItems.contains(itemIdentifier)
       
        return cell
    }
    
    // MARK: - Lifecycle
    
    init(
        mediaManager: MediaBrowserMediaManager,
        tapDelegate: (any MediaBrowserTapDelegate)?
    ) {
        self.mediaManager = mediaManager
        self.tapDelegate = tapDelegate
        
        super.init(frame: .zero, collectionViewLayout: MediaBrowserGridCollectionView.layout)
        delegate = self
       
        configure()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Configure
    
    private func configure() {
        registerCells()
        dataSource = gridDataSource
        mediaManager.register(delegate: gridDataSource)

        // The footer is not reconfigured with the items, so its count is updated here
        gridDataSource.onDidApplySnapshot = { [weak self] in
            self?.updateFooter()
        }
    }
    
    private func registerCells() {
        registerCell(MediaBrowserGridCollectionViewCell.self)
    }
    
    private func updateFooter() {
        for case let footer as MediaBrowserGridFooterView in visibleSupplementaryViews(
            ofKind: UICollectionView.elementKindSectionFooter
        ) {
            footer.text = gridDataSource.footerText
        }
    }
    
    // MARK: - Public functions
    
    /// Scrolls to the item if it is not visible
    func visibleCell(for objectID: NSManagedObjectID) -> UICollectionViewCell? {
        guard let indexPath = gridDataSource.indexPath(for: objectID) else {
            return nil
        }

        if !indexPathsForVisibleItems.contains(indexPath) {
            scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
            layoutIfNeeded()
        }

        return cellForItem(at: indexPath)
    }
    
    /// Starts selection tracking and tells cells to adapt layout
    func startSelection() {
        mode = .multiselect
        allowsMultipleSelection = true
        
        for cell in visibleCells {
            guard let mediaCell = cell as? MediaBrowserGridCollectionViewCell else {
                continue
            }
            
            mediaCell.isMultiselecting = true
        }
    }
    
    /// Ends and resets selection tracking and tells cells to adapt layout
    func cancelSelection() {
        mode = .default
        allowsMultipleSelection = false
        selectedItems.removeAll()
        
        for cell in visibleCells {
            guard let mediaCell = cell as? MediaBrowserGridCollectionViewCell else {
                continue
            }
            
            mediaCell.isMultiselecting = false
        }
    }
    
    func selectAll() {
        selectedItems = Set(mediaManager.allObjectIDs)

        for section in 0..<numberOfSections {
            for item in 0..<numberOfItems(inSection: section) {
                selectItem(at: IndexPath(item: item, section: section), animated: false, scrollPosition: [])
            }
        }

        visibleCells.compactMap { $0 as? MediaBrowserGridCollectionViewCell }.forEach {
            $0.isMultiselected = true
        }
    }

    func deselectAll() {
        selectedItems.removeAll()

        indexPathsForSelectedItems?.forEach {
            deselectItem(at: $0, animated: false)
        }

        visibleCells.compactMap { $0 as? MediaBrowserGridCollectionViewCell }.forEach {
            $0.isMultiselected = false
        }
    }
    
    // MARK: - UICollectionViewDelegate
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
     
        guard let objectID = gridDataSource.objectID(for: indexPath) else {
            DDLogError("[Media Browser] Failed to get objectID ")
            return
        }
        
        switch mode {
        case .default:
            tapDelegate?.didTap(message: objectID)
            deselectItem(at: indexPath, animated: false)
            
        case .multiselect:
            selectedItems.insert(objectID)
            
            if let cell = collectionView.cellForItem(at: indexPath) as? MediaBrowserGridCollectionViewCell {
                cell.isMultiselected = true
            }
            
            tapDelegate?.selectionChanged()
        }
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        guard mode == .multiselect, let objectID = gridDataSource.objectID(for: indexPath) else {
            return
        }
        
        selectedItems.remove(objectID)
        
        if let cell = collectionView.cellForItem(at: indexPath) as? MediaBrowserGridCollectionViewCell {
            cell.isMultiselected = false
        }
        
        tapDelegate?.selectionChanged()
    }
}
