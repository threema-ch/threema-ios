import FLAnimatedImage
import Foundation
import ThreemaFramework
import ThreemaMacros

/// Full screen page of the media browser, showing an image, an animated image or a video poster
final class MediaBrowserPageCollectionViewCell: UICollectionViewCell, UIScrollViewDelegate, Reusable {

    static let reuseIdentifier = "MediaBrowserPageCollectionViewCell"

    private enum Configuration {
        static let minimumZoomScale = 1.0
        static let maximumZoomScale = 4.0
        static let doubleTapZoomScale = 2.5
        static let doubleTapZoomOutDuration: TimeInterval = 0.3
        static let circleButtonSize: CGFloat = 75
        static let missingDataFadeDuration: TimeInterval = 0.25
        /// Like the thumbnails in the chat
        static let stateAndProgressSpacing: CGFloat = 12
        static let missingDataInfoInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        static let missingDataInfoCornerRadius: CGFloat = 16
        static let missingDataInfoSpacing: CGFloat = 8
    }

    /// State of the data shown instead of the content if it is not available
    private enum MissingDataState: Equatable {
        case none
        case remote
        case downloading(progress: Float)
        case deleted
        case notFound

        init(message: FileMessageProvider) {
            guard !message.isDataAvailable else {
                self = .none
                return
            }

            switch message.blobDisplayState {
            case let .downloading(progress: progress):
                self = .downloading(progress: progress)
            case .dataDeleted:
                self = .deleted
            case .fileNotFound:
                self = .notFound
            default:
                self = .remote
            }
        }
    }

    // MARK: - Public properties

    var onTap: (() -> Void)?
    var onPlay: (() -> Void)?
    var onDownload: (() -> Void)?
    var onCancelDownload: (() -> Void)?
    
    var onWillZoom: (() -> Void)?
    var onDidZoomOut: (() -> Void)?

    // MARK: - Private properties

    /// Identifies the shown message, without depending on Core Data types
    private var identifier: URL?
    private var isDataAvailable = false
    private var missingDataState: MissingDataState = .none

    /// The image is only fitted again if the size changes
    private var lastImageLayoutSize: CGSize = .zero
    private var isZooming = false

    private lazy var singleTapGestureRecognizer: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(didTap))
        recognizer.require(toFail: doubleTapGestureRecognizer)
        return recognizer
    }()

    private lazy var doubleTapGestureRecognizer: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(didDoubleTap(_:)))
        recognizer.numberOfTapsRequired = 2
        return recognizer
    }()

    // MARK: - Subviews

    // Image

    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.delegate = self

        scrollView.minimumZoomScale = Configuration.minimumZoomScale
        scrollView.maximumZoomScale = Configuration.maximumZoomScale

        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.isHidden = true

        scrollView.translatesAutoresizingMaskIntoConstraints = false

        return scrollView
    }()

    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        return imageView
    }()

    // Animated image

    private lazy var animatedImageView: FLAnimatedImageView = {
        let view = FLAnimatedImageView()
        view.contentMode = .scaleAspectFit
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // Video

    private lazy var videoThumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private lazy var videoPlayButton = makeCircleButton(symbolName: "play.fill", action: #selector(didTapPlay))

    // Missing data

    /// Thumbnail shown instead of the content until it is downloaded
    private lazy var missingDataImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    /// Downloads or cancels the download, otherwise only shows the state
    private lazy var stateCircleView: UIView = {
        let view = makeCircleButton(symbolName: "arrow.down", action: #selector(didTapState))
        view.isAccessibilityElement = true
        return view
    }()

    /// Like the progress of the thumbnails in the chat
    private lazy var progressView: UIProgressView = {
        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.trackTintColor = .clear
        progressView.progressTintColor = Colors.thumbnailProgressViewColor
        progressView.alpha = 0.75
        progressView.translatesAutoresizingMaskIntoConstraints = false
        return progressView
    }()

    /// Why deleted or missing data cannot be shown, readable on any thumbnail
    private lazy var missingDataInfoView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        view.layer.cornerRadius = Configuration.missingDataInfoCornerRadius
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        view.isAccessibilityElement = true

        let stack = UIStackView(arrangedSubviews: [missingDataSymbolView, missingDataLabel])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = Configuration.missingDataInfoSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.contentView.addSubview(stack)

        let insets = Configuration.missingDataInfoInsets
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.contentView.leadingAnchor, constant: insets.leading),
            stack.trailingAnchor.constraint(equalTo: view.contentView.trailingAnchor, constant: -insets.trailing),
            stack.topAnchor.constraint(equalTo: view.contentView.topAnchor, constant: insets.top),
            stack.bottomAnchor.constraint(equalTo: view.contentView.bottomAnchor, constant: -insets.bottom),
        ])

        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var missingDataSymbolView: UIImageView = {
        let imageView = UIImageView()
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .body)
        imageView.tintColor = .label
        return imageView
    }()

    private lazy var missingDataLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        return label
    }()

    private var missingDataViews: [UIView] {
        [missingDataImageView, stateCircleView, progressView, missingDataInfoView]
    }

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        identifier = nil
        isDataAvailable = false
        onTap = nil
        onPlay = nil
        onWillZoom = nil
        onDidZoomOut = nil
        onDownload = nil
        onCancelDownload = nil

        resetContent()

        missingDataState = .none
        missingDataImageView.image = nil
        missingDataInfoView.alpha = 1
        for view in missingDataViews {
            view.isHidden = true
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Otherwise the scroll view has no size yet on the first layout
        contentView.layoutIfNeeded()
        updateImageLayoutIfNeeded()
    }

    // MARK: - Configuration

    private func configureViews() {
        scrollView.addSubview(imageView)
        contentView.addSubview(scrollView)
        contentView.addSubview(animatedImageView)
        contentView.addSubview(videoThumbnailImageView)
        contentView.addSubview(videoPlayButton)

        // Above the content, which it covers while the data is missing
        for view in missingDataViews {
            view.isHidden = true
            contentView.addSubview(view)
        }

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            animatedImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            animatedImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            animatedImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            animatedImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            videoThumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            videoThumbnailImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            videoThumbnailImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            videoThumbnailImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            videoPlayButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            videoPlayButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            missingDataImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            missingDataImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            missingDataImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            missingDataImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            stateCircleView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stateCircleView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            progressView.topAnchor.constraint(
                equalTo: stateCircleView.bottomAnchor,
                constant: Configuration.stateAndProgressSpacing
            ),
            progressView.leadingAnchor.constraint(equalTo: stateCircleView.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: stateCircleView.trailingAnchor),

            missingDataInfoView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            missingDataInfoView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            missingDataInfoView.leadingAnchor.constraint(
                greaterThanOrEqualTo: contentView.layoutMarginsGuide.leadingAnchor
            ),
        ])

        contentView.addGestureRecognizer(doubleTapGestureRecognizer)
        contentView.addGestureRecognizer(singleTapGestureRecognizer)
    }

    /// Only updates the cell for the same message if the data availability changed, so e.g. download progress updates
    /// do not reset the zoom
    /// - Parameters:
    ///   - identifier: Identifies the message, e.g. the URI representation of its object ID
    ///   - message: Message to show
    func configure(identifier: URL, message: FileMessageProvider) {
        let isSameMessage = identifier == self.identifier

        // Always updated, e.g. with the download progress
        updateMissingData(for: message, isSameMessage: isSameMessage)

        guard !isSameMessage || message.isDataAvailable != isDataAvailable else {
            return
        }

        self.identifier = identifier
        isDataAvailable = message.isDataAvailable

        resetContent()

        guard isDataAvailable else {
            if missingDataState == .deleted || missingDataState == .notFound,
               let data = message.blobThumbnail, let thumbnail = UIImage(data: data) {
                showZoomableImage(thumbnail)
            }
            return
        }

        switch message.fileMessageType {
        case .image, .sticker:
            configureForImage(message: message)

        case .animatedImage, .animatedSticker:
            configureForAnimatedImage(message: message)

        case .video:
            configureForVideo(message: message)

        case .voice, .file:
            // Can pass the media filter, e.g. a media file message with a mime type we cannot render
            break
        }
    }

    private func resetContent() {
        scrollView.zoomScale = Configuration.minimumZoomScale
        lastImageLayoutSize = .zero
        isZooming = false

        imageView.image = nil
        animatedImageView.animatedImage = nil
        videoThumbnailImageView.image = nil

        scrollView.isHidden = true
        animatedImageView.isHidden = true
        videoThumbnailImageView.isHidden = true
        videoPlayButton.isHidden = true

        doubleTapGestureRecognizer.isEnabled = false
    }

    // MARK: - Circle buttons

    /// Glass button like the system controls, a blurred circle before iOS 26
    private func makeCircleButton(symbolName: String, action: Selector) -> UIView {
        let circleButton: UIView

        if #available(iOS 26.0, *) {
            var configuration = UIButton.Configuration.glass()
            configuration.image = UIImage(systemName: symbolName, withConfiguration: circleButtonSymbolConfiguration)
            configuration.cornerStyle = .capsule

            let button = UIButton(configuration: configuration)
            button.addTarget(self, action: action, for: .touchUpInside)

            let size = UIFontMetrics(forTextStyle: .title1).scaledValue(for: Configuration.circleButtonSize)
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: size),
                button.heightAnchor.constraint(equalToConstant: size),
            ])

            circleButton = button
        }
        else {
            let blurCircleView = BlurCircleView(sfSymbolName: symbolName, configuration: .galleryPage)
            blurCircleView.isUserInteractionEnabled = true
            blurCircleView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: action))
            circleButton = blurCircleView
        }

        circleButton.isHidden = true
        circleButton.translatesAutoresizingMaskIntoConstraints = false

        return circleButton
    }

    private func setSymbol(_ symbolName: String, of circleButton: UIView) {
        if let button = circleButton as? UIButton {
            button.configuration?.image = UIImage(
                systemName: symbolName,
                withConfiguration: circleButtonSymbolConfiguration
            )
        }
        else if let blurCircleView = circleButton as? BlurCircleView {
            blurCircleView.updateSymbol(to: symbolName)
        }
    }

    private var circleButtonSymbolConfiguration: UIImage.SymbolConfiguration {
        UIImage.SymbolConfiguration(textStyle: .title1, scale: .large)
            .applying(UIImage.SymbolConfiguration(weight: .bold))
    }

    // MARK: - Missing data

    private func updateMissingData(for message: FileMessageProvider, isSameMessage: Bool) {
        let previousState = isSameMessage ? missingDataState : .none
        let state = MissingDataState(message: message)
        missingDataState = state

        switch state {
        case .none:
            hideMissingData(animated: previousState != .none)

        case .remote, .downloading:
            // The thumbnail is only decoded once, not on every progress update
            if previousState == .none {
                missingDataImageView.image = message.blobThumbnail.flatMap { UIImage(data: $0) }
            }

            setSymbol(message.blobDisplayState.symbolName ?? "arrow.down", of: stateCircleView)
            if case let .downloading(progress) = state {
                stateCircleView.accessibilityLabel = #localize("cancel")
                progressView.setProgress(progress, animated: previousState != .none)
                progressView.isHidden = false
            }
            else {
                stateCircleView.accessibilityLabel = #localize("download")
                progressView.setProgress(0, animated: false)
                progressView.isHidden = true
            }

            missingDataImageView.isHidden = false
            stateCircleView.isHidden = false
            missingDataInfoView.isHidden = true

        case .deleted, .notFound:
            // Cannot be downloaded anymore, so the thumbnail is shown zoomable like the content instead
            let text = state == .deleted ? #localize("file_deleted_title") : #localize("file_not_found_title")
            missingDataSymbolView.image = message.blobDisplayState.symbolName.flatMap { UIImage(systemName: $0) }
            missingDataLabel.text = text
            missingDataInfoView.accessibilityLabel = text
            if !isSameMessage {
                // Might have been faded out while zoomed into another message
                missingDataInfoView.alpha = 1
            }

            missingDataImageView.isHidden = true
            stateCircleView.isHidden = true
            progressView.isHidden = true
            missingDataInfoView.isHidden = false
        }
    }

    /// The thumbnail of deleted or missing data can be looked at without the info while zoomed
    private func setMissingDataInfoVisible(_ isVisible: Bool) {
        guard missingDataState == .deleted || missingDataState == .notFound else {
            return
        }

        UIView.animate(withDuration: Configuration.missingDataFadeDuration) {
            self.missingDataInfoView.alpha = isVisible ? 1 : 0
        }
    }

    /// Fades out over the content after a download
    private func hideMissingData(animated: Bool) {
        guard animated else {
            for view in missingDataViews {
                view.isHidden = true
            }
            return
        }

        UIView.animate(withDuration: Configuration.missingDataFadeDuration) {
            for view in self.missingDataViews {
                view.alpha = 0
            }
        } completion: { _ in
            for view in self.missingDataViews {
                view.isHidden = true
                view.alpha = 1
            }
            self.missingDataImageView.image = nil
        }
    }

    private func configureForImage(message: FileMessageProvider) {
        guard let data = message.blobData, let image = UIImage(data: data) else {
            return
        }

        showZoomableImage(image)
    }

    private func showZoomableImage(_ image: UIImage) {
        imageView.image = image
        scrollView.isHidden = false
        doubleTapGestureRecognizer.isEnabled = true

        setNeedsLayout()
    }

    private func configureForAnimatedImage(message: FileMessageProvider) {
        guard let data = message.blobData, let animatedImage = FLAnimatedImage(animatedGIFData: data) else {
            return
        }

        animatedImageView.animatedImage = animatedImage
        animatedImageView.isHidden = false
    }

    private func configureForVideo(message: FileMessageProvider) {
        if let thumbnailData = message.blobThumbnail {
            videoThumbnailImageView.image = UIImage(data: thumbnailData)
        }

        videoThumbnailImageView.isHidden = false
        videoPlayButton.isHidden = false
    }

    // MARK: - Image layout

    private func updateImageLayoutIfNeeded() {
        guard !scrollView.isHidden,
              let imageSize = imageView.image?.size,
              imageSize.width > 0, imageSize.height > 0 else {
            return
        }

        let scrollSize = scrollView.bounds.size
        guard scrollSize.width > 0, scrollSize.height > 0, scrollSize != lastImageLayoutSize else {
            return
        }

        // Fitting the image again while zoomed would make it jump, it is fitted when zoomed out completely
        guard !isZooming, scrollView.zoomScale == Configuration.minimumZoomScale else {
            centerImageInScrollView()
            return
        }
        lastImageLayoutSize = scrollSize

        let scale = min(scrollSize.width / imageSize.width, scrollSize.height / imageSize.height)
        let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)

        imageView.frame = CGRect(origin: .zero, size: fittedSize)
        scrollView.contentSize = fittedSize

        centerImageInScrollView()
    }

    private func centerImageInScrollView() {
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) / 2, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) / 2, 0)
        scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
    }

    // MARK: - UIScrollViewDelegate

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        isZooming = true
        setMissingDataInfoVisible(false)
        onWillZoom?()
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        isZooming = false

        if scale == Configuration.minimumZoomScale {
            didZoomOutCompletely()
        }
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImageInScrollView()
    }

    private func didZoomOutCompletely() {
        isZooming = false
        setMissingDataInfoVisible(true)
        // The size might have changed while zoomed
        setNeedsLayout()
        onDidZoomOut?()
    }

    // MARK: - Actions

    @objc private func didTap() {
        // Animated images are played and paused by tapping
        guard !animatedImageView.isHidden else {
            onTap?()
            return
        }

        if animatedImageView.isAnimating {
            animatedImageView.stopAnimating()
        }
        else {
            animatedImageView.startAnimating()
        }
    }

    @objc private func didDoubleTap(_ recognizer: UITapGestureRecognizer) {
        guard scrollView.zoomScale == scrollView.minimumZoomScale else {
            // `scrollViewDidEndZooming` is not called for zooming programmatically
            UIView.animate(withDuration: Configuration.doubleTapZoomOutDuration) {
                self.scrollView.zoomScale = self.scrollView.minimumZoomScale
            } completion: { _ in
                self.didZoomOutCompletely()
            }
            return
        }

        isZooming = true
        setMissingDataInfoVisible(false)
        onWillZoom?()

        let point = recognizer.location(in: imageView)
        let size = CGSize(
            width: scrollView.bounds.width / Configuration.doubleTapZoomScale,
            height: scrollView.bounds.height / Configuration.doubleTapZoomScale
        )
        let rect = CGRect(
            x: point.x - size.width / 2,
            y: point.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        scrollView.zoom(to: rect, animated: true)
    }

    @objc private func didTapPlay() {
        onPlay?()
    }

    @objc private func didTapState() {
        switch missingDataState {
        case .remote:
            onDownload?()
        case .downloading:
            onCancelDownload?()
        case .none, .deleted, .notFound:
            break
        }
    }
}
