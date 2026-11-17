import Foundation
import ThreemaMacros

protocol MediaBrowserTapDelegate: AnyObject {
    func didTap(message objectID: NSManagedObjectID)
    func selectionChanged()
}

/// View controller for the grid and the list collection views
final class MediaBrowserCollectionViewController: UIViewController, MediaBrowserTapDelegate {
    
    // MARK: - Types
    enum Segments: Int, CaseIterable {
        case media
        case files
        
        var localizedTitle: String {
            switch self {
            case .media:
                #localize("media_browser_segment_media")
            case .files:
                #localize("media_browser_segment_files")
            }
        }
    }
    
    enum Configuration {
        static let navigationBarAnimationDuration = 0.2
        static let segmentedControlInsets = NSDirectionalEdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16)
    }
    
    // MARK: - Private properties

    private let mediaManager: MediaBrowserMediaManager
    private let onSelectMediaItem: (NSManagedObjectID) -> Void
    private let onClose: () -> Void

    private var hasScrolledToInitialPosition = false
    
    // MARK: - Subviews
    
    private lazy var closeButtonItem: UIBarButtonItem =
        UIBarButtonItem.closeButton(target: self, selector: #selector(dismissAction))
    
    private lazy var startSelectionItem: UIBarButtonItem =
        UIBarButtonItem.selectButton(target: self, selector: #selector(startSelection))
    
    private lazy var cancelSelectionItem: UIBarButtonItem =
        UIBarButtonItem.cancelButton(target: self, selector: #selector(cancelSelection))
    
    private lazy var selectAllItem: UIBarButtonItem = {
        let item = UIBarButtonItem(
            title: #localize("select_all"),
            style: .plain,
            target: self,
            action: #selector(selectAllTapped)
        )
        item.tintColor = .label
        
        return item
    }()
    
    private lazy var selectionToolbar: UIToolbar = {
        let toolbar = UIToolbar()
        toolbar.isHidden = true
        
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        
        return toolbar
    }()
    
    private lazy var selectionToolbarConstraints: [NSLayoutConstraint] = [
        selectionToolbar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
        selectionToolbar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
        selectionToolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
    ]
    
    private lazy var deleteButton = UIBarButtonItem.deleteButton(target: self, selector: #selector(didTapDelete))

    private lazy var shareButton = UIBarButtonItem.shareButton(target: self, selector: #selector(didTapShare))

    private lazy var spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

    private lazy var selectionCountLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .headline)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var selectionCountContainer: UIView = {
        if #available(iOS 26.0, *) {
            let glassView = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
            glassView.translatesAutoresizingMaskIntoConstraints = false
            glassView.cornerConfiguration = .uniformCorners(
                radius: UICornerRadius(floatLiteral: 30)
            )
            glassView.contentView.addSubview(selectionCountLabel)
           
            NSLayoutConstraint.activate([
                selectionCountLabel.leadingAnchor.constraint(equalTo: glassView.contentView.leadingAnchor, constant: 12),
                selectionCountLabel.trailingAnchor.constraint(
                    equalTo: glassView.contentView.trailingAnchor,
                    constant: -12
                ),
                selectionCountLabel.centerYAnchor.constraint(equalTo: glassView.contentView.centerYAnchor),
            ])
            
            return glassView
        }
        else {
            let view = UIView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(selectionCountLabel)
            NSLayoutConstraint.activate([
                selectionCountLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                selectionCountLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                selectionCountLabel.topAnchor.constraint(equalTo: view.topAnchor),
                selectionCountLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
            return view
        }
    }()
    
    private lazy var selectionCountConstraints: [NSLayoutConstraint] = [
        selectionCountContainer.centerXAnchor.constraint(equalTo: selectionToolbar.centerXAnchor),
        selectionCountContainer.centerYAnchor.constraint(equalTo: selectionToolbar.centerYAnchor),
        selectionCountContainer.heightAnchor.constraint(equalTo: selectionToolbar.heightAnchor),
    ]

    private lazy var segmentedControl: UISegmentedControl = {
        let items = Segments.allCases.map(\.localizedTitle)
        let control = UISegmentedControl(items: items)
        control.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        control.selectedSegmentIndex = 0
        return control
    }()
    
    /// Row below the navigation bar, looking like a part of it
    private lazy var segmentedControlBar: UIView = {
        let bar: UIView
        if #available(iOS 26.0, *) {
            // Extends the scroll edge effect of the navigation bar below the row
            bar = UIView()
            let interaction = UIScrollEdgeElementContainerInteraction()
            interaction.scrollView = gridCollectionView
            interaction.edge = .top
            bar.addInteraction(interaction)
        }
        else {
            // Same material as the navigation bar, which always shows its background in the grid
            bar = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
        }

        let contentView = (bar as? UIVisualEffectView)?.contentView ?? bar
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(segmentedControl)
        NSLayoutConstraint.activate([
            segmentedControl.leadingAnchor.constraint(
                equalTo: contentView.safeAreaLayoutGuide.leadingAnchor,
                constant: Configuration.segmentedControlInsets.leading
            ),
            segmentedControl.trailingAnchor.constraint(
                equalTo: contentView.safeAreaLayoutGuide.trailingAnchor,
                constant: -Configuration.segmentedControlInsets.trailing
            ),
            segmentedControl.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: Configuration.segmentedControlInsets.top
            ),
            segmentedControl.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -Configuration.segmentedControlInsets.bottom
            ),
        ])

        bar.translatesAutoresizingMaskIntoConstraints = false
        return bar
    }()

    private lazy var gridCollectionView: MediaBrowserGridCollectionView = {
        let grid = MediaBrowserGridCollectionView(
            mediaManager: mediaManager,
            tapDelegate: self
        )
        
        grid.translatesAutoresizingMaskIntoConstraints = false
        
        return grid
    }()
    
    private lazy var gridConstraints: [NSLayoutConstraint] = [
        gridCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        gridCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        gridCollectionView.topAnchor.constraint(equalTo: view.topAnchor),
        gridCollectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ]
    
    private lazy var listCollectionView: UIView = {
        let list = MediaBrowserListCollectionView()
        list.backgroundColor = .blue
        
        list.translatesAutoresizingMaskIntoConstraints = false
        
        return list
    }()
    
    private lazy var listConstraints: [NSLayoutConstraint] = [
        listCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        listCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        listCollectionView.topAnchor.constraint(equalTo: view.topAnchor),
        listCollectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ]
    
    // MARK: - Lifecycle
    
    init(
        mediaManager: MediaBrowserMediaManager,
        onSelectMediaItem: @escaping (NSManagedObjectID) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.mediaManager = mediaManager
        self.onSelectMediaItem = onSelectMediaItem
        self.onClose = onClose
        
        super.init(nibName: nil, bundle: nil)
        
        isModalInPresentation = true

        configureLayout()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        // The initial scroll position needs the insets, which are only final in the window
        view.setNeedsLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // The grid starts below the row, which is placed in this additional safe area
        let barHeight = segmentedControlBar.bounds.height
        if additionalSafeAreaInsets.top != barHeight {
            additionalSafeAreaInsets.top = barHeight
        }

        // We start at the end of the grid with the number of media. Only in the window all insets are known.
        guard !hasScrolledToInitialPosition,
              view.window != nil,
              gridCollectionView.contentSize.height > 0 else {
            return
        }
        hasScrolledToInitialPosition = true

        // Headers and footer have estimated heights, the content height must be final
        gridCollectionView.layoutIfNeeded()
        let insets = gridCollectionView.adjustedContentInset
        let endOffset = gridCollectionView.contentSize.height + insets.bottom - gridCollectionView.bounds.height
        gridCollectionView.contentOffset.y = max(endOffset, -insets.top)
    }
    
    // MARK: - Layout
    
    private func configureLayout() {
        title = #localize("media_browser_title")
        navigationItem.leftBarButtonItem = startSelectionItem
        navigationItem.rightBarButtonItem = closeButtonItem
        
        if #unavailable(iOS 26.0) {
            // Matches the row below, also when the grid is scrolled to the top
            let appearance = UINavigationBarAppearance()
            appearance.configureWithDefaultBackground()
            navigationItem.scrollEdgeAppearance = appearance
        }

        view.addSubview(segmentedControlBar)
        NSLayoutConstraint.activate([
            segmentedControlBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            segmentedControlBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            segmentedControlBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
        ])
        
        view.addSubview(selectionToolbar)
        NSLayoutConstraint.activate(selectionToolbarConstraints)
        
        var items: [UIBarButtonItem] = [deleteButton, spacer]
        if !MDMSetup().disableShareMedia() {
            items.append(shareButton)
        }
        selectionToolbar.setItems(items, animated: false)

        // To not have a bar button item with interaction, we must add the count directly as a subview
        selectionToolbar.addSubview(selectionCountContainer)
        NSLayoutConstraint.activate(selectionCountConstraints)
        
        showGrid()
    }
    
    private func showGrid() {
        view.insertSubview(gridCollectionView, at: 0)
        NSLayoutConstraint.activate(gridConstraints)
    }
    
    private func hideGrid() {
        gridCollectionView.cancelSelection()
        gridCollectionView.removeFromSuperview()
    }
    
    private func showList() {
        view.insertSubview(listCollectionView, at: 0)
        NSLayoutConstraint.activate(listConstraints)
    }
    
    private func hideList() {
        listCollectionView.removeFromSuperview()
    }
    
    // MARK: - Actions
    
    @objc private func segmentChanged() {
        guard let selectedCase = Segments(rawValue: segmentedControl.selectedSegmentIndex) else {
            return
        }
        
        cancelSelection()
        
        switch selectedCase {
        case .media:
            hideList()
            showGrid()
            
        case .files:
            hideGrid()
            showList()
        }
    }
    
    @objc private func dismissAction() {
        onClose()
    }
    
    @objc private func didTapShare() {
        guard !MDMSetup().disableShareMedia() else {
            return
        }

        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.startAnimating()
        shareButton.customView = spinner

        Task { [weak self] in
            guard let self else {
                return
            }
            
            await mediaManager.shareMessages(
                with: gridCollectionView.selectedObjectIDs,
                source: shareButton,
                presentationController: self
            )
            shareButton.customView = nil
            cancelSelection()
        }
    }
        
    @objc private func didTapDelete() {
        UIAlertTemplate.showDestructiveAlert(
            owner: self,
            title: #localize("media_browser_delete_selected_title"),
            message: nil,
            titleDestructive: #localize("delete")
        ) { [weak self] _ in
            guard let self else {
                return
            }
                
            mediaManager.deleteMessages(with: gridCollectionView.selectedObjectIDs)
            cancelSelection()
        }
    }
    
    // MARK: - Selection
    
    @objc private func startSelection() {
        guard let selectedCase = Segments(rawValue: segmentedControl.selectedSegmentIndex) else {
            return
        }
        
        selectionChanged()

        UIView.animate(withDuration: Configuration.navigationBarAnimationDuration) { [weak self] in
            guard let self else {
                return
            }
            
            navigationItem.leftBarButtonItem = selectAllItem
            navigationItem.rightBarButtonItems = [cancelSelectionItem]
            selectionToolbar.isHidden = false
            
        } completion: { [weak self] _ in
            guard let self else {
                return
            }
            
            switch selectedCase {
            case .media:
                gridCollectionView.startSelection()
                
            case .files:
                // TODO:
                return
            }
        }
    }
    
    @objc private func cancelSelection() {
        guard let selectedCase = Segments(rawValue: segmentedControl.selectedSegmentIndex) else {
            return
        }
        
        UIView.animate(withDuration: Configuration.navigationBarAnimationDuration) { [weak self] in
            guard let self else {
                return
            }
            
            navigationItem.leftBarButtonItem = startSelectionItem
            navigationItem.rightBarButtonItems = [closeButtonItem]
            selectionToolbar.isHidden = true
            
        } completion: { [weak self] _ in
            guard let self else {
                return
            }
            
            switch selectedCase {
            case .media:
                gridCollectionView.cancelSelection()

            case .files:
                // TODO:
                return
            }
        }
    }
    
    @objc private func selectAllTapped() {
        guard let selectedCase = Segments(rawValue: segmentedControl.selectedSegmentIndex) else {
            return
        }
        
        switch selectedCase {
        case .media:
            if gridCollectionView.allSelected {
                gridCollectionView.deselectAll()
            }
            else {
                gridCollectionView.selectAll()
            }
            
        case .files:
            // TODO:
            break
        }
        
        selectionChanged()
    }

    // MARK: - MediaBrowserTapDelegate
    
    func selectionChanged() {
        guard let selectedCase = Segments(rawValue: segmentedControl.selectedSegmentIndex) else {
            return
        }
        
        let allSelected: Bool
        let selectedCount: Int
        switch selectedCase {
        case .media:
            allSelected = gridCollectionView.allSelected
            selectedCount = gridCollectionView.selectedCount

        case .files:
            // TODO:
            return
        }

        selectionCountLabel.text = String.localizedStringWithFormat(
            #localize("media_browser_selection_count"),
            selectedCount,
            gridCollectionView.totalCount
        )
        
        if selectedCount == 0 {
            deleteButton.isEnabled = false
            shareButton.isEnabled = false
        }
        else {
            deleteButton.isEnabled = true
            shareButton.isEnabled = true
        }
        
        UIView.animate(withDuration: Configuration.navigationBarAnimationDuration) { [weak self] in
            guard let self else {
                return
            }
            
            selectAllItem.title = allSelected ? #localize("deselect_all") : #localize("select_all")
        }
    }
    
    func didTap(message objectID: NSManagedObjectID) {
        guard let message = mediaManager.fileMessageEntity(for: objectID) else {
            return
        }
        
        // Several items can be downloaded quickly in the grid, the pager is only opened for downloaded items or to
        // explain missing data
        switch message.blobDisplayState {
        case .remote:
            mediaManager.download(objectID)
            
        case .processed, .pending, .uploading, .uploaded, .sendingError:
            if case .outgoing(.pendingDownload) = message.dataState {
                mediaManager.download(objectID)
                return
            }
            
            presentFullScreenView(for: objectID)
            
        case .downloading:
            mediaManager.cancelDownload(objectID)
            
        case .dataDeleted, .fileNotFound:
            presentFullScreenView(for: objectID)
        }
    }
    
    private func presentFullScreenView(for objectID: NSManagedObjectID) {
        onSelectMediaItem(objectID)
    }

    // MARK: - Zoom transition

    /// Cell of the item for the zoom transition from and to the pager
    func zoomSourceCell(for objectID: NSManagedObjectID) -> MediaBrowserGridCollectionViewCell? {
        // The initial scroll position is set on the first layout, which must not move the item away afterwards
        view.layoutIfNeeded()
        return gridCollectionView.visibleCell(for: objectID) as? MediaBrowserGridCollectionViewCell
    }
}
