import UIKit

/// Glass bubble with caption, sender, date, size and type of the current page, floating over the media
final class MediaBrowserPageInfoView: UIView {

    struct Info {
        let senderDisplayName: String
        let dateString: String
        let sizeString: String
        /// SF Symbol or custom symbol
        let typeSymbolName: String
        let durationString: String?
        let caption: String?
    }

    private enum Configuration {
        static let cornerRadius: CGFloat = 30
        static let contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        static let collapsedCaptionLineLimit = 1
        static let expandedCaptionLineLimit = 12
        static let captionSpacing: CGFloat = 8
        static let captionDividerHeight: CGFloat = 1
        static let verticalSpacing: CGFloat = 2
        static let horizontalSpacing: CGFloat = 8
        static let animationDuration: TimeInterval = 0.25
    }

    // MARK: - Public properties

    var info: Info? {
        didSet {
            isCaptionExpanded = info?.caption != nil
            updateContent()
        }
    }

    // MARK: - Private properties

    private var isCaptionExpanded = false

    // MARK: - Subviews

    private lazy var backgroundView: UIVisualEffectView = {
        let view: UIVisualEffectView
        
        if #available(iOS 26.0, *) {
            view = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
            view.cornerConfiguration = .uniformCorners(radius: UICornerRadius(floatLiteral: Configuration.cornerRadius))
        }
        else {
            view = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
            view.layer.cornerRadius = Configuration.cornerRadius
            view.layer.cornerCurve = .continuous
            view.clipsToBounds = true
        }
       
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var captionLabel: UILabel = {
        let label = makeLabel(textStyle: .body, color: .label)
        label.numberOfLines = Configuration.collapsedCaptionLineLimit
        label.isUserInteractionEnabled = true
        label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapCaption)))
        return label
    }()

    private lazy var senderLabel = makeLabel(textStyle: .subheadline, color: .label)
    private lazy var dateLabel = makeLabel(textStyle: .footnote, color: .secondaryLabel)
    private lazy var metadataLabel = makeLabel(textStyle: .footnote, color: .secondaryLabel)

    private lazy var dateRow: UIStackView = {
        // The date truncates before the metadata
        dateLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        dateLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        metadataLabel.setContentHuggingPriority(.required, for: .horizontal)
        metadataLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [dateLabel, metadataLabel])
        stack.axis = .horizontal
        stack.alignment = .firstBaseline
        stack.spacing = Configuration.horizontalSpacing
        return stack
    }()

    private lazy var captionDivider: UIView = {
        let view = UIView()
        view.backgroundColor = .separator
        return view
    }()

    private lazy var contentStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [captionLabel, captionDivider, senderLabel, dateRow])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = Configuration.verticalSpacing
        stack.setCustomSpacing(Configuration.captionSpacing, after: captionLabel)
        stack.setCustomSpacing(Configuration.captionSpacing, after: captionDivider)
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        configureViews()
        updateLargeTextLayout()

        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: Self, _: UITraitCollection) in
            self.updateLargeTextLayout()
            // The symbol in the metadata is sized when it is created
            self.metadataLabel.attributedText = self.info.map { self.metadataText(for: $0) }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configuration

    private func configureViews() {
        addSubview(backgroundView)
        backgroundView.contentView.addSubview(contentStack)

        let contentView = backgroundView.contentView
        NSLayoutConstraint.activate([
            captionDivider.heightAnchor.constraint(equalToConstant: Configuration.captionDividerHeight),

            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentStack.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: Configuration.contentInsets.leading
            ),
            contentStack.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -Configuration.contentInsets.trailing
            ),
            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Configuration.contentInsets.top),
            contentStack.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -Configuration.contentInsets.bottom
            ),
        ])
    }

    private func makeLabel(textStyle: UIFont.TextStyle, color: UIColor) -> UILabel {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: textStyle)
        label.textColor = color
        label.adjustsFontForContentSizeCategory = true
        label.maximumContentSizeCategory = .extraExtraExtraLarge
        return label
    }

    private func updateContent() {
        senderLabel.text = info?.senderDisplayName
        dateLabel.text = info?.dateString
        metadataLabel.attributedText = info.map { metadataText(for: $0) }

        // New texts change the label widths, which must not be animated with a caption change
        UIView.performWithoutAnimation {
            dateRow.layoutIfNeeded()
        }

        captionLabel.text = info?.caption
        captionLabel.isHidden = info?.caption == nil
        captionDivider.isHidden = captionLabel.isHidden
        updateCaptionExpansion(animated: false)
    }

    /// Duration of videos, symbol of the media type and size, e.g. "0:32 · 🎞 12 MB"
    private func metadataText(for info: Info) -> NSAttributedString {
        let text = NSMutableAttributedString()

        if let durationString = info.durationString {
            text.append(NSAttributedString(string: "\(durationString) · "))
        }

        // Custom symbols like the video one are not system symbols
        let symbolConfiguration = UIImage.SymbolConfiguration(textStyle: .footnote)
        let symbol = UIImage(systemName: info.typeSymbolName, withConfiguration: symbolConfiguration)
            ?? UIImage(named: info.typeSymbolName, in: nil, with: symbolConfiguration)
        if let symbol {
            // As a template the attachment takes the text color
            text.append(
                NSAttributedString(attachment: NSTextAttachment(image: symbol.withRenderingMode(.alwaysTemplate)))
            )
            text.append(NSAttributedString(string: " "))
        }

        text.append(NSAttributedString(string: info.sizeString))

        return text
    }

    private func updateLargeTextLayout() {
        let isLarge = traitCollection.preferredContentSizeCategory >= .extraExtraExtraLarge

        dateRow.axis = isLarge ? .vertical : .horizontal
        dateRow.alignment = isLarge ? .leading : .firstBaseline
    }

    // MARK: - Caption

    private func updateCaptionExpansion(animated: Bool) {
        captionLabel.numberOfLines = isCaptionExpanded
            ? Configuration.expandedCaptionLineLimit
            : Configuration.collapsedCaptionLineLimit

        guard animated else {
            return
        }

        // The bubble grows upwards, which is laid out by the superview
        UIView.animate(withDuration: Configuration.animationDuration) {
            (self.superview ?? self).layoutIfNeeded()
        }
    }

    @objc private func didTapCaption() {
        // Only captions longer than one line can be collapsed
        guard captionLabel.exceeds(
            lines: Configuration.collapsedCaptionLineLimit,
            availableWidth: captionLabel.bounds.width
        ) else {
            return
        }

        isCaptionExpanded.toggle()
        updateCaptionExpansion(animated: true)
    }
}
