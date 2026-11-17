
import Foundation

final class MediaBrowserGridCollectionViewCell: UICollectionViewCell, Reusable {
    
    static let reuseIdentifier = "MediaBrowserGridCollectionViewCell"
    
    private enum Configuration {
        static let metaDataInset: CGFloat = 4
        static let progressViewDistance: CGFloat = 4
    }
    
    // MARK: - Public properties
    
    var thumbnailDisplayMessage: ThumbnailDisplayMessage? {
        didSet {
            updateCell()
        }
    }
    
    /// Thumbnail shown in the cell, e.g. for the zoom transition
    var thumbnailImage: UIImage? {
        thumbnailImageView.isHidden ? nil : thumbnailImageView.image
    }
    
    // We do not override `isSelected` because of collection views internals when dequeuing cells
    var isMultiselected: Bool = false {
        didSet {
            updateSelection(selected: isMultiselected)
        }
    }
    
    var isMultiselecting: Bool = false {
        didSet {
            updateIsMultiselecting()
        }
    }
    
    // MARK: - Private properties
        
    private lazy var fileSizeFormatter = ByteCountFormatter()
    private lazy var progressFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        return formatter
    }()
    
    // MARK: - Subviews
    
    private lazy var thumbnailImageView: UIImageView = {
        let thumbnailImageView = UIImageView()
        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.clipsToBounds = true
        thumbnailImageView.backgroundColor = .secondarySystemFill
        thumbnailImageView.isHidden = true
        
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        
        return thumbnailImageView
    }()
    
    private lazy var thumbnailImageViewConstraints: [NSLayoutConstraint] = [
        thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        thumbnailImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
        thumbnailImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        thumbnailImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
    ]
    
    private lazy var centerStateBlurView: BlurCircleView = {
        let blurCircleView = BlurCircleView(sfSymbolName: "person.fill.turn.down", configuration: .galleryGrid)
        
        blurCircleView.isHidden = true
        blurCircleView.translatesAutoresizingMaskIntoConstraints = false
        
        return blurCircleView
    }()
    
    private lazy var centerStateBlurViewConstraints: [NSLayoutConstraint] = [
        centerStateBlurView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        centerStateBlurView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
    ]
    
    private lazy var progressView: UIProgressView = {
        let progressView = UIProgressView(progressViewStyle: .default)
        
        progressView.trackTintColor = .clear
        progressView.isHidden = true
        progressView.progressTintColor = Colors.thumbnailProgressViewColor
        
        progressView.translatesAutoresizingMaskIntoConstraints = false

        return progressView
    }()
    
    private lazy var progressViewConstraints: [NSLayoutConstraint] = [
        progressView.topAnchor.constraint(
            equalTo: centerStateBlurView.bottomAnchor,
            constant: Configuration.progressViewDistance
        ),
        progressView.leadingAnchor.constraint(equalTo: centerStateBlurView.leadingAnchor),
        progressView.trailingAnchor.constraint(equalTo: centerStateBlurView.trailingAnchor),
    ]
    
    private lazy var metadataView = MessageSymbolMetadataVibrancyView()
    private lazy var metadataBlurBackgroundContainerView: MessageMetadataBlurBackgroundView = {
        let view = MessageMetadataBlurBackgroundView(
            rootView: metadataView.vibrancyAffectedView,
            nonVibrantRootView: metadataView.vibrancyUnaffectedView
        )
        
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        
        return view
    }()
    
    private lazy var metadataViewConstraints: [NSLayoutConstraint] = [
        metadataBlurBackgroundContainerView.trailingAnchor.constraint(
            equalTo: contentView.trailingAnchor,
            constant: -Configuration.metaDataInset
        ),
        metadataBlurBackgroundContainerView.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor,
            constant: -Configuration.metaDataInset
        ),
    ]
    
    private lazy var checkMarkView: UIImageView = {
        let image = UIImage(systemName: "checkmark.circle.fill")?
            .applying(paletteColors: [.white, .primary])
        let view = UIImageView(image: image)

        view.contentMode = .scaleAspectFit
        view.layer.cornerRadius = 13
        view.layer.masksToBounds = true
        view.layer.borderWidth = 2
        view.layer.borderColor = UIColor.white.cgColor

        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false

        return view
    }()
    
    private lazy var checkMarkViewConstraints: [NSLayoutConstraint] = [
        checkMarkView.widthAnchor.constraint(equalToConstant: 26),
        checkMarkView.heightAnchor.constraint(equalToConstant: 26),
        checkMarkView.trailingAnchor.constraint(
            equalTo: contentView.trailingAnchor,
            constant: -Configuration.metaDataInset
        ),
        checkMarkView.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor,
            constant: -Configuration.metaDataInset
        ),
    ]
    
    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        thumbnailImageView.image = nil
        thumbnailImageView.isHidden = true
        centerStateBlurView.isHidden = true
        metadataBlurBackgroundContainerView.isHidden = true
        progressView.isHidden = true
        progressView.progress = 0
        checkMarkView.isHidden = true
    }
    
    // MARK: - Configuration
    func configure() {
        // We add all the views hidden, so we do not need to take care of adding them when updating the cell
        contentView.addSubview(thumbnailImageView)
        NSLayoutConstraint.activate(thumbnailImageViewConstraints)
        
        contentView.addSubview(centerStateBlurView)
        NSLayoutConstraint.activate(centerStateBlurViewConstraints)
        
        contentView.addSubview(metadataBlurBackgroundContainerView)
        NSLayoutConstraint.activate(metadataViewConstraints)
        
        contentView.addSubview(progressView)
        NSLayoutConstraint.activate(progressViewConstraints)
        
        contentView.addSubview(checkMarkView)
        NSLayoutConstraint.activate(checkMarkViewConstraints)
    }
    
    private func updateCell() {
        guard let message = thumbnailDisplayMessage else {
            thumbnailImageView.isHidden = true
            centerStateBlurView.isHidden = true
            metadataBlurBackgroundContainerView.isHidden = true
            progressView.isHidden = true
            return
        }
        
        updateImage(message: message)
        updateCenterBlurView(message: message)
        updateMetaDataView(message: message)
        updateProgressView(message: message)
    }
    
    private func updateImage(message: ThumbnailDisplayMessage) {
        if let image = message.thumbnailImage {
            thumbnailImageView.image = image
            thumbnailImageView.isHidden = false
        }
        else {
            thumbnailImageView.isHidden = true
        }
    }
    
    private func updateCenterBlurView(message: ThumbnailDisplayMessage) {
        if let symbolName = message.blobDisplayState.symbolName {
            centerStateBlurView.updateSymbol(to: symbolName)
            centerStateBlurView.isHidden = false
        }
        else {
            centerStateBlurView.isHidden = true
        }
    }
    
    private func updateMetaDataView(message: ThumbnailDisplayMessage) {
        if case let .downloading(progress: progress) = message.blobDisplayState {
            metadataView.symbolName = message.fileMessageType.symbolName

            metadataBlurBackgroundContainerView.isHidden = false
            if let progressString = progressFormatter.string(from: Double(progress) as NSNumber) {
                metadataView.metadataString = """
                    \(fileSizeFormatter.string(for: message.dataBlobFileSize) ?? "") \
                    (\(progressString))
                    """
            }
            else {
                metadataView.metadataString = fileSizeFormatter.string(for: message.dataBlobFileSize)
            }
            metadataBlurBackgroundContainerView.isHidden = false
        }
        else if message.blobDisplayState == .remote {
            metadataView.symbolName = message.fileMessageType.symbolName
            metadataView.metadataString = fileSizeFormatter.string(for: message.dataBlobFileSize)
            metadataBlurBackgroundContainerView.isHidden = false
        }
        else if case let .video(message) = message.fileMessageType, let duration = message.durationTimeInterval {
            metadataView.symbolName = message.fileMessageType.symbolName
            metadataView.metadataString = DateFormatter.timeFormatted(Int(duration))
            metadataBlurBackgroundContainerView.isHidden = false
        }
        else {
            metadataBlurBackgroundContainerView.isHidden = true
        }
    }
    
    private func updateProgressView(message: ThumbnailDisplayMessage) {
        if case let .downloading(progress: progress) = message.blobDisplayState {
            progressView.isHidden = false
            progressView.progress = progress
        }
        else {
            progressView.isHidden = true
        }
    }
    
    private func updateSelection(selected: Bool) {
        checkMarkView.isHidden = !selected
    }
    
    private func updateIsMultiselecting() {
        if isMultiselecting {
            metadataBlurBackgroundContainerView.isHidden = true
            centerStateBlurView.isHidden = true
            progressView.isHidden = true
        }
        else {
            isMultiselected = false
            checkMarkView.isHidden = true
            updateCell()
        }
    }
}
