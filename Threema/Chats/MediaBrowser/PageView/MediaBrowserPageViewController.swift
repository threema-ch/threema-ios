import AudioSessionManager
import AVKit
import CocoaLumberjackSwift
import FileUtility
import Foundation
import ThreemaFramework
import ThreemaMacros

/// Full screen pager of the media browser, a horizontally paging collection view with one page per media item
final class MediaBrowserPageViewController: UIViewController,
    UICollectionViewDelegate,
    MediaBrowserMediaManagerDelegate {

    private enum Configuration {
        static let animationDuration: TimeInterval = 0.25
        static let verticalSpacing: CGFloat = 12
    }

    private enum Section {
        case main
    }

    // MARK: - Private properties

    private let mediaManager: MediaBrowserMediaManager
    private let onClose: () -> Void

    /// Item of the current page, also before the pager is laid out
    var shownObjectID: NSManagedObjectID? {
        currentObjectID ?? pendingObjectID
    }

    /// Frame of the media area in the view
    var mediaFrame: CGRect {
        collectionView.frame
    }

    /// Hides the media, e.g. while a zoom transition animates a snapshot of it
    var isMediaHidden: Bool {
        get { collectionView.isHidden }
        set { collectionView.isHidden = newValue }
    }

    private var currentObjectID: NSManagedObjectID? {
        didSet {
            guard currentObjectID != oldValue else {
                return
            }
            updateNavigationBar()
            updateInfo()
            updateShareButton()
            stripView.select(currentObjectID, animated: true)
        }
    }

    /// Scrolled to as soon as the collection view is laid out and contains it
    private var pendingObjectID: NSManagedObjectID?

    /// Set while we change the content offset or size, so the current page is not updated from it
    private var isAdjustingLayout = false
    private var lastLayoutWidth: CGFloat = 0

    private var overlaysHidden = false

    // Video playback, like in the chat
    private let audioSessionManager: any AudioSessionManagerProtocol = BusinessInjector.ui.audioSessionManager
    private var audioSessionClaim: AudioSessionClaim?
    private var playedVideoURL: URL?
    private var isVideoPictureInPicture = false
    /// Zooming out completely only shows the overlays again if zooming in hid them
    private var overlaysHiddenForZoom = false

    // MARK: - Subviews

    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: MediaBrowserPageViewController.layout
        )
        collectionView.delegate = self
        collectionView.isPagingEnabled = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.backgroundColor = .clear
        collectionView.registerCell(MediaBrowserPageCollectionViewCell.self)

        collectionView.translatesAutoresizingMaskIntoConstraints = false

        return collectionView
    }()

    private static var layout: UICollectionViewCompositionalLayout {
        let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
        let item = NSCollectionLayoutItem(layoutSize: size)
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: size, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        // Pages fill the whole media area, e.g. on the full screen of the sheet, not only its safe area
        section.contentInsetsReference = .none

        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .horizontal
        configuration.contentInsetsReference = .none

        return UICollectionViewCompositionalLayout(section: section, configuration: configuration)
    }

    private lazy var dataSource = UICollectionViewDiffableDataSource<Section, NSManagedObjectID>(
        collectionView: collectionView
    ) { [weak self] collectionView, indexPath, objectID in
        guard let self else {
            return nil
        }

        let cell: MediaBrowserPageCollectionViewCell = collectionView.dequeueCell(for: indexPath)

        if let message = mediaManager.fileMessageProvider(for: objectID) {
            cell.configure(identifier: objectID.uriRepresentation(), message: message)
        }
        cell.onTap = { [weak self] in
            self?.toggleOverlays()
        }
        cell.onPlay = { [weak self] in
            self?.playVideo(for: objectID)
        }
        cell.onDownload = { [weak self] in
            self?.mediaManager.download(objectID)
        }
        cell.onCancelDownload = { [weak self] in
            self?.mediaManager.cancelDownload(objectID)
        }
        cell.onWillZoom = { [weak self] in
            guard let self, !overlaysHidden else {
                return
            }
            showMediaOnFullScreen()
            overlaysHiddenForZoom = overlaysHidden
        }
        cell.onDidZoomOut = { [weak self] in
            guard let self, overlaysHiddenForZoom else {
                return
            }
            setOverlaysHidden(false, animated: true)
        }

        return cell
    }

    private lazy var toolbar: UIToolbar = {
        let toolbar = UIToolbar()

        // Like the strip, the toolbar floats on the background
        let appearance = UIToolbarAppearance()
        appearance.configureWithTransparentBackground()
        toolbar.standardAppearance = appearance
        toolbar.compactAppearance = appearance
        toolbar.scrollEdgeAppearance = appearance
        toolbar.compactScrollEdgeAppearance = appearance

        toolbar.translatesAutoresizingMaskIntoConstraints = false
        return toolbar
    }()

    private lazy var stripView: MediaBrowserPageStripView = {
        let stripView = MediaBrowserPageStripView(mediaManager: mediaManager)
        stripView.onSelect = { [weak self] objectID in
            self?.showPageFromStrip(for: objectID)
        }
        stripView.translatesAutoresizingMaskIntoConstraints = false
        return stripView
    }()

    private lazy var infoView: MediaBrowserPageInfoView = {
        let infoView = MediaBrowserPageInfoView()
        infoView.translatesAutoresizingMaskIntoConstraints = false
        return infoView
    }()

    private lazy var cancelButton = UIBarButtonItem.cancelButton(target: self, selector: #selector(close))

    private lazy var gridButton: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: UIImage(systemName: "square.grid.2x2"),
            primaryAction: UIAction { [weak self] _ in
                self?.showGrid()
            }
        )
        item.accessibilityLabel = #localize("media_browser_title")
        return item
    }()

    /// Asks for confirmation in a menu above the button
    private lazy var deleteButton: UIBarButtonItem = {
        let deleteAction = UIAction(
            title: #localize("delete"),
            image: UIImage(systemName: "trash"),
            attributes: .destructive
        ) { [weak self] _ in
            self?.deleteCurrentMessage()
        }
        let menu = UIMenu(title: #localize("media_browser_delete_item_title"), children: [deleteAction])

        let item = UIBarButtonItem(image: UIImage(systemName: "trash"), menu: menu)
        item.tintColor = .label
        item.accessibilityLabel = #localize("delete")
        return item
    }()

    private lazy var shareButton = UIBarButtonItem.shareButton(target: self, selector: #selector(didTapShare))

    private lazy var spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

    private lazy var byteCountFormatter = ByteCountFormatter()

    /// The info overlaps the media
    private lazy var mediaWithOverlaysConstraints: [NSLayoutConstraint] = [
        collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
        collectionView.bottomAnchor.constraint(equalTo: stripView.topAnchor, constant: -Configuration.verticalSpacing),
    ]

    private lazy var mediaFullScreenConstraints: [NSLayoutConstraint] = [
        collectionView.topAnchor.constraint(equalTo: view.topAnchor),
        collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ]

    private var overlayViews: [UIView] {
        [infoView, stripView, toolbar]
    }

    // MARK: - Lifecycle

    /// - Parameters:
    ///   - onClose: Called to close the whole media browser
    init(
        mediaManager: MediaBrowserMediaManager,
        objectID: NSManagedObjectID,
        onClose: @escaping () -> Void
    ) {
        self.mediaManager = mediaManager
        self.onClose = onClose
        self.pendingObjectID = objectID

        super.init(nibName: nil, bundle: nil)

        // Like the grid, the sheet is only closed with the close button
        isModalInPresentation = true

        mediaManager.register(delegate: self)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(voiceOverStatusDidChange),
            name: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        mediaManager.unregister(delegate: self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        currentObjectID = pendingObjectID
        applySnapshot(for: mediaManager.allObjectIDs, reconfigureIDs: [], animated: false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let width = collectionView.bounds.width
        guard width > 0 else {
            return
        }

        // Keep the current page when the size changes, e.g. on rotation
        if width != lastLayoutWidth {
            lastLayoutWidth = width
            pendingObjectID = pendingObjectID ?? currentObjectID
        }

        scrollToPendingObjectIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        // The navigation bar is shared with the grid
        setOverlaysHidden(false, animated: animated)

        super.viewWillDisappear(animated)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        // The current page is kept in `viewDidLayoutSubviews`
        isAdjustingLayout = true
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            self?.isAdjustingLayout = false
        }
    }

    // MARK: - Configure

    private func configure() {
        view.backgroundColor = .systemBackground
        navigationItem.leftBarButtonItem = gridButton
        navigationItem.rightBarButtonItem = cancelButton

        view.addSubview(collectionView)
        view.addSubview(infoView)
        view.addSubview(stripView)
        view.addSubview(toolbar)

        NSLayoutConstraint.activate(mediaWithOverlaysConstraints)
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            // Aligned with the toolbar buttons
            infoView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            infoView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            infoView.bottomAnchor.constraint(equalTo: stripView.topAnchor, constant: -Configuration.verticalSpacing),

            stripView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stripView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stripView.bottomAnchor.constraint(equalTo: toolbar.topAnchor, constant: -Configuration.verticalSpacing),

            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        let items: [UIBarButtonItem] = MDMSetup().disableShareMedia()
            ? [spacer, deleteButton]
            : [shareButton, spacer, deleteButton]
        toolbar.setItems(items, animated: false)
    }

    // MARK: - Layout

    private func updateNavigationBar() {
        guard let currentObjectID,
              let indexPath = dataSource.indexPath(for: currentObjectID),
              collectionView.numberOfSections > 0 else {
            title = nil
            return
        }

        title = String.localizedStringWithFormat(
            #localize("media_browser_page_vc_title"),
            indexPath.item + 1,
            collectionView.numberOfItems(inSection: 0)
        )
    }

    /// Only downloaded data can be shared
    private func updateShareButton() {
        shareButton.isEnabled = currentObjectID
            .flatMap { mediaManager.fileMessageProvider(for: $0)?.isDataAvailable } ?? false
    }

    private func updateInfo() {
        let info = currentObjectID.flatMap { info(for: $0) }
        infoView.info = info
        infoView.isHidden = info == nil

        guard isViewLoaded, view.window != nil else {
            return
        }

        // The bubble might change its height, the cells must not be part of the animation
        collectionView.layoutIfNeeded()
        UIView.animate(withDuration: Configuration.animationDuration) {
            self.view.layoutIfNeeded()
        }
    }

    private func info(for objectID: NSManagedObjectID) -> MediaBrowserPageInfoView.Info? {
        guard let message = mediaManager.thumbnailDisplayMessage(for: objectID) else {
            return nil
        }

        let displayName = mediaManager.senderName(for: objectID) ?? #localize("unknown")
        let dateString = DateFormatter.relativeMediumDateAndShortTime(for: message.displayDate)

        var durationString: String?
        if case let .video(videoMessage) = message.fileMessageType, let duration = videoMessage.durationTimeInterval {
            durationString = DateFormatter.timeFormatted(Int(duration))
        }

        let sizeString = byteCountFormatter.string(for: message.dataBlobFileSize) ?? ""

        return MediaBrowserPageInfoView.Info(
            senderDisplayName: displayName,
            dateString: dateString,
            sizeString: sizeString,
            typeSymbolName: message.fileMessageType.symbolName,
            durationString: durationString,
            // An empty caption is shown like no caption
            caption: message.caption.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        )
    }

    private func scrollToPendingObjectIfNeeded() {
        guard let pendingObjectID,
              collectionView.bounds.width > 0,
              let indexPath = dataSource.indexPath(for: pendingObjectID) else {
            return
        }

        self.pendingObjectID = nil
        showPage(at: indexPath)
    }

    private func showPageFromStrip(for objectID: NSManagedObjectID) {
        guard let indexPath = dataSource.indexPath(for: objectID), collectionView.bounds.width > 0 else {
            return
        }

        showPage(at: indexPath)
    }

    private func showPage(at indexPath: IndexPath) {
        // `scrollToItem` is unreliable with paging enabled
        let wasAdjustingLayout = isAdjustingLayout
        isAdjustingLayout = true
        collectionView.layoutIfNeeded()
        collectionView.contentOffset = CGPoint(x: CGFloat(indexPath.item) * collectionView.bounds.width, y: 0)
        isAdjustingLayout = wasAdjustingLayout

        currentObjectID = dataSource.itemIdentifier(for: indexPath)
    }

    private func toggleOverlays() {
        if overlaysHidden {
            setOverlaysHidden(false, animated: true)
        }
        else if canShowCurrentPageOnFullScreen {
            showMediaOnFullScreen()
        }
    }

    /// Not while only the thumbnail of downloadable data is shown, deleted or missing data shows its thumbnail instead
    private var canShowCurrentPageOnFullScreen: Bool {
        guard let currentObjectID, let message = mediaManager.fileMessageProvider(for: currentObjectID) else {
            return false
        }

        switch message.blobDisplayState {
        case .dataDeleted, .fileNotFound:
            return true
        default:
            return message.isDataAvailable
        }
    }

    private func showMediaOnFullScreen() {
        // With VoiceOver the actions in the overlays must stay reachable
        guard !UIAccessibility.isVoiceOverRunning else {
            return
        }

        setOverlaysHidden(true, animated: true)
    }

    private func setOverlaysHidden(_ hidden: Bool, animated: Bool) {
        guard hidden != overlaysHidden else {
            return
        }
        overlaysHidden = hidden
        overlaysHiddenForZoom = false

        if hidden {
            NSLayoutConstraint.deactivate(mediaWithOverlaysConstraints)
            NSLayoutConstraint.activate(mediaFullScreenConstraints)
        }
        else {
            NSLayoutConstraint.deactivate(mediaFullScreenConstraints)
            NSLayoutConstraint.activate(mediaWithOverlaysConstraints)
        }

        // We fade the navigation bar instead of hiding it, so the safe area does not change. Its buttons are hidden as
        // well, otherwise they are shown again e.g. while the sheet is pulled down.
        let isAnimated = animated && isViewLoaded && view.window != nil
        let navigationBar = navigationController?.navigationBar
        navigationBar?.isUserInteractionEnabled = !hidden
        for item in [navigationItem.leftBarButtonItem, navigationItem.rightBarButtonItem] {
            item?.isHidden = hidden
        }
        for overlayView in overlayViews {
            overlayView.isUserInteractionEnabled = !hidden
        }

        let changes = {
            navigationBar?.alpha = hidden ? 0 : 1
            for overlayView in self.overlayViews {
                overlayView.alpha = hidden ? 0 : 1
            }
            self.view.backgroundColor = hidden ? .black : .systemBackground
            self.view.layoutIfNeeded()
        }

        guard isAnimated else {
            UIView.performWithoutAnimation(changes)
            return
        }

        UIView.animate(
            withDuration: Configuration.animationDuration,
            delay: 0,
            options: [.beginFromCurrentState, .curveEaseInOut],
            animations: changes
        )
    }

    @objc private func voiceOverStatusDidChange() {
        if UIAccessibility.isVoiceOverRunning {
            setOverlaysHidden(false, animated: true)
        }
    }

    // MARK: - Actions

    @objc private func close() {
        onClose()
    }

    private func showGrid() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func didTapShare() {
        guard !MDMSetup().disableShareMedia() else {
            return
        }

        guard let currentObjectID else {
            DDLogError("[MediaBrowser] Failed to get objectID for current page")
            return
        }

        Task {
            await mediaManager.shareMessages(
                with: [currentObjectID],
                source: shareButton,
                presentationController: self
            )
        }
    }

    private func deleteCurrentMessage() {
        guard let currentObjectID else {
            DDLogError("[MediaBrowser] Failed to get objectID for current page")
            return
        }

        mediaManager.deleteMessages(with: [currentObjectID])
    }

    private func playVideo(for objectID: NSManagedObjectID) {
        guard let videoMessage = mediaManager.fileMessageProvider(for: objectID) as? VideoMessage,
              let url = videoMessage.temporaryBlobDataURL() else {
            return
        }

        playedVideoURL = url

        // Created for each video, so the player is released after it is closed
        let player = AVPlayer(url: url)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        playerViewController.delegate = self

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            // Without the audio session for media playback, the mute button of the player shows a wrong state
            do {
                audioSessionClaim = try await audioSessionManager.acquire(.mediaPlayback)
            }
            catch {
                NotificationPresenterWrapper.shared.present(type: .playbackFailed)
                DDLogError("[MediaBrowser] Failed to acquire audio session: \(error)")
            }

            present(playerViewController, animated: true) {
                player.play()
            }
        }
    }

    // MARK: - Snapshot

    private func applySnapshot(
        for objectIDs: [NSManagedObjectID],
        reconfigureIDs: [NSManagedObjectID],
        animated: Bool
    ) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, NSManagedObjectID>()
        snapshot.appendSections([.main])
        snapshot.appendItems(objectIDs, toSection: .main)
        snapshot.reconfigureItems(reconfigureIDs)

        stripView.apply(objectIDs: objectIDs, reconfigureIDs: reconfigureIDs)

        dataSource.apply(snapshot, animatingDifferences: animated) { [weak self] in
            guard let self else {
                return
            }
            updateNavigationBar()
            scrollToPendingObjectIfNeeded()
        }
    }

    /// Page to show if the current one was removed: the closest previous one that still exists, otherwise the next one
    private func replacementObjectID(
        for removedObjectID: NSManagedObjectID,
        oldObjectIDs: [NSManagedObjectID],
        newObjectIDs: Set<NSManagedObjectID>
    ) -> NSManagedObjectID? {
        guard let index = oldObjectIDs.firstIndex(of: removedObjectID) else {
            return nil
        }

        let previous = oldObjectIDs[..<index].last { newObjectIDs.contains($0) }
        let next = oldObjectIDs[(index + 1)...].first { newObjectIDs.contains($0) }

        return previous ?? next
    }

    // MARK: - UIScrollViewDelegate

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !isAdjustingLayout, pendingObjectID == nil else {
            return
        }

        // Updates the current page while swiping
        let center = CGPoint(x: collectionView.bounds.midX, y: collectionView.bounds.midY)
        guard let indexPath = collectionView.indexPathForItem(at: center),
              let objectID = dataSource.itemIdentifier(for: indexPath) else {
            return
        }

        currentObjectID = objectID
    }

    // MARK: - MediaBrowserMediaManagerDelegate

    func mediaChanged(
        _ source: MediaBrowserMediaManager,
        didUpdateObjectIDs objectIDs: [NSManagedObjectID],
        reloadIDs: [NSManagedObjectID],
        reconfigureIDs: [NSManagedObjectID]
    ) {
        // Otherwise the latest media is applied when the view loads
        guard isViewLoaded else {
            return
        }

        guard !objectIDs.isEmpty else {
            showGrid()
            return
        }

        let newObjectIDs = Set(objectIDs)
        if let currentObjectID, !newObjectIDs.contains(currentObjectID) {
            let replacement = replacementObjectID(
                for: currentObjectID,
                oldObjectIDs: dataSource.snapshot().itemIdentifiers,
                newObjectIDs: newObjectIDs
            )
            pendingObjectID = replacement
            self.currentObjectID = replacement
        }

        applySnapshot(for: objectIDs, reconfigureIDs: reloadIDs + reconfigureIDs, animated: true)

        // E.g. a download of the current message finished
        if let currentObjectID, reloadIDs.contains(currentObjectID) || reconfigureIDs.contains(currentObjectID) {
            updateInfo()
            updateShareButton()
        }
    }
}

// MARK: - AVPlayerViewControllerDelegate

extension MediaBrowserPageViewController: AVPlayerViewControllerDelegate {

    // Like in the chat: closing picture in picture also closes the player, so we only clean up after one of them

    func playerViewController(
        _ playerViewController: AVPlayerViewController,
        willEndFullScreenPresentationWithAnimationCoordinator coordinator: any UIViewControllerTransitionCoordinator
    ) {
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            guard let self, !isVideoPictureInPicture else {
                return
            }
            releaseAudioSessionAndDeleteVideoFile()
        }
    }

    func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        isVideoPictureInPicture = true
    }

    func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        isVideoPictureInPicture = false
        releaseAudioSessionAndDeleteVideoFile()
    }

    private func releaseAudioSessionAndDeleteVideoFile() {
        if let audioSessionClaim {
            self.audioSessionClaim = nil
            let audioSessionManager = audioSessionManager
            Task {
                await audioSessionManager.release(audioSessionClaim)
            }
        }

        FileUtility.shared.deleteIfExists(at: playedVideoURL)
        playedVideoURL = nil
    }
}
