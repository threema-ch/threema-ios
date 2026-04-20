import ThreemaMacros
import UIKit

final class MessageForwardingFileMessageView: UIStackView {

    // MARK: - Private types

    private enum Layout {
        static let cornerRadius: CGFloat = 8.0
        static let barWidth: CGFloat = 2.0
        static let barCornerRadius: CGFloat = 1.0
        static let spacing: CGFloat = 8.0
        static let thumbnailWidth: CGFloat = 60.0
        static let dividerHeight: CGFloat = 1.0

        enum Container {
            static let margins = NSDirectionalEdgeInsets(top: 8.0, leading: 8.0, bottom: 8.0, trailing: 8.0)
        }

        enum Caption {
            static let spacing: CGFloat = 4.0
            static let iconSpacing: CGFloat = 2.0
        }

        enum Thumbnail {
            static let iconScale: CGFloat = 0.65
        }
    }

    // MARK: - Internal properties

    var onForwardCaptionValueChanged: ((Bool) -> Void)?
    var onSendAsFileValueChanged: ((Bool) -> Void)?

    // MARK: - Private properties

    private weak var delegate: (any ChatTextViewDelegate)?
    private let markupParser = MarkupParser()

    private let symbol: String?
    private let localizedDescription: String
    private let thumbnail: Data?
    private let caption: String?

    private var isForwardingCaption = true

    private lazy var messageStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.alignment = .top
        stackView.spacing = Layout.spacing
        stackView.setContentCompressionResistancePriority(.required, for: .vertical)
        return stackView
    }()

    private lazy var dividerView: UIView = {
        let view = UIView()
        view.backgroundColor = .separator
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: Layout.dividerHeight / UIScreen.main.scale),
        ])
        return view
    }()

    private lazy var toggleStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [toggleLabel, toggleSwitch])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = Layout.spacing
        stackView.setContentCompressionResistancePriority(.required, for: .vertical)
        stackView.setContentHuggingPriority(.required, for: .vertical)
        return stackView
    }()

    private lazy var toggleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.text = #localize("send_as_file")
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }()

    private lazy var toggleSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.onTintColor = .primary
        toggle.isOn = false
        toggle.addTarget(self, action: #selector(toggleSwitchValueChanged), for: .valueChanged)
        toggle.setContentCompressionResistancePriority(.required, for: .vertical)
        toggle.setContentHuggingPriority(.required, for: .vertical)
        return toggle
    }()

    private lazy var chatTextView: ChatTextView = {
        let view = ChatTextView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBackground
        view.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        view.chatTextViewDelegate = delegate
        view.placeholderTextValue = #localize("message_forwarding_input_placeholder")
        view.placeholderVerticalPosition = .top
        view.customMinHeight = Layout.thumbnailWidth
        view.customCornerRadius = Layout.cornerRadius
        return view
    }()

    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(makeCloseButtonImage(), for: .normal)
        button.tintColor = .secondaryLabel
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        return button
    }()

    private lazy var thumbnailView: UIView =
        if let thumbnailData = thumbnail,
        let uiImage = UIImage(data: thumbnailData) {
            createImageThumbnail(with: uiImage)
        }
        else {
            createIconThumbnail()
        }

    private lazy var captionContainerView: UIStackView = {
        let buttonContainer = createCloseButtonContainer()
        let stackView = UIStackView(arrangedSubviews: [barView, captionContentStack, buttonContainer])
        stackView.spacing = Layout.spacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.backgroundColor = .systemBackground
        stackView.layer.cornerRadius = Layout.cornerRadius
        stackView.clipsToBounds = true
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.directionalLayoutMargins = Layout.Container.margins

        return stackView
    }()

    private lazy var mediaTypeStack: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [iconImageView, fileTypeLabel])
        stackView.spacing = Layout.Caption.iconSpacing
        stackView.alignment = .center
        stackView.distribution = .fill
        return stackView
    }()

    private lazy var captionContentStack: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [mediaTypeStack, captionLabel, spacerView])
        stackView.axis = .vertical
        stackView.spacing = Layout.Caption.spacing
        return stackView
    }()

    private lazy var barView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondaryLabel
        view.layer.cornerRadius = Layout.barCornerRadius
        view.layer.masksToBounds = true

        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: Layout.barWidth),
        ])

        return view
    }()

    private lazy var iconImageView: UIImageView = {
        let config = UIImage.SymbolConfiguration(font: .preferredFont(forTextStyle: .caption1))
        let image = UIImage(systemName: symbol ?? "") ?? UIImage(named: symbol ?? "")
        let imageView = UIImageView(image: image)
        imageView.preferredSymbolConfiguration = config
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .secondaryLabel
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)

        return imageView
    }()

    private lazy var fileTypeLabel: UILabel = {
        let label = UILabel()
        label.adjustsFontForContentSizeCategory = true
        label.font = .preferredFont(forTextStyle: .caption1)
        label.text = localizedDescription
        label.textColor = .secondaryLabel
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }()

    private lazy var captionLabel: UILabel = {
        let label = UILabel()
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .left
        label.numberOfLines = 2
        label.textColor = .label
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }()

    private lazy var spacerView: UIView = {
        let spacer = UIView()
        spacer.setContentCompressionResistancePriority(.defaultLow - 1, for: .vertical)
        return spacer
    }()

    private lazy var captionContainerHeightConstraint = captionContainerView.heightAnchor.constraint(
        greaterThanOrEqualTo: thumbnailView.heightAnchor
    )

    // MARK: - Lifecycle

    init(
        symbol: String?,
        description: String,
        thumbnail: Data?,
        caption: String?,
        delegate: any ChatTextViewDelegate
    ) {
        self.delegate = delegate
        self.symbol = symbol
        self.localizedDescription = description
        self.thumbnail = thumbnail
        self.caption = caption

        super.init(frame: .zero)

        configureStackView()
        setupSubviews()
        setupTraitRegistration()
        updateContentForCurrentSizeCategory()
        updateContentForCurrenSizeClass()
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Internal methods

    func getTipAnchorView() -> UIView {
        closeButton
    }

    // MARK: - Private methods

    private func configureStackView() {
        translatesAutoresizingMaskIntoConstraints = false
        axis = .vertical
        distribution = .fill
        spacing = Layout.spacing
        isLayoutMarginsRelativeArrangement = true
        directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 0,
            leading: 0,
            bottom: Layout.spacing,
            trailing: 0
        )
    }

    private func setupSubviews() {
        addArrangedSubview(messageStackView)
        addArrangedSubview(dividerView)
        addArrangedSubview(toggleStackView)
        configureMessageStackView()
    }

    private func configureMessageStackView() {
        messageStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        messageStackView.addArrangedSubview(thumbnailView)

        if caption != nil, isForwardingCaption {
            messageStackView.addArrangedSubview(captionContainerView)
        }
        else {
            messageStackView.addArrangedSubview(chatTextView)
        }

        updateContentForCurrentSizeCategory()
        updateContentForCurrenSizeClass()
    }

    private func createImageThumbnail(with image: UIImage) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.image = image
        imageView.backgroundColor = .systemBackground
        imageView.layer.cornerRadius = Layout.cornerRadius
        imageView.clipsToBounds = true
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)

        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: Layout.thumbnailWidth),
            imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: 1.0),
        ])

        return imageView
    }

    private func createIconThumbnail() -> UIView {
        let image = UIImage(systemName: symbol ?? "") ?? UIImage(named: symbol ?? "")
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tintColor = .secondaryLabel

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .systemBackground
        container.layer.cornerRadius = Layout.cornerRadius
        container.clipsToBounds = true
        container.setContentHuggingPriority(.defaultLow, for: .horizontal)
        container.addSubview(imageView)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: Layout.thumbnailWidth),
            container.widthAnchor.constraint(equalTo: container.heightAnchor, multiplier: 1.0),
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            imageView.widthAnchor.constraint(
                equalTo: container.widthAnchor,
                multiplier: Layout.Thumbnail.iconScale
            ),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor),
        ])

        return container
    }

    private func createCloseButtonContainer() -> UIView {
        let container = UIView()
        container.addSubview(closeButton)

        NSLayoutConstraint.activate([
            closeButton.widthAnchor.constraint(equalTo: container.widthAnchor),
            closeButton.topAnchor.constraint(equalTo: container.topAnchor),
            closeButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
        ])

        return container
    }

    private func updateContentForCurrentSizeCategory() {
        closeButton.setImage(makeCloseButtonImage(), for: .normal)
        closeButton.sizeToFit()

        updateToggleStackView()
        updateCaptionText()
        setNeedsLayout()
        layoutIfNeeded()
    }

    private func updateContentForCurrenSizeClass() {
        let hasCompactVerticalSizeClass = traitCollection.verticalSizeClass == .compact
        if hasCompactVerticalSizeClass {
            thumbnailView.isHidden = true
            spacerView.isHidden = true

            chatTextView.allowsVerticalGrowing = false
            chatTextView.customMinHeight = nil
            chatTextView.customCornerRadius = nil

            if caption != nil, isForwardingCaption {
                captionContentStack.axis = .horizontal
                captionContainerHeightConstraint.isActive = false
                captionLabel.numberOfLines = 1
            }
        }
        else {
            thumbnailView.isHidden = false
            spacerView.isHidden = false

            chatTextView.allowsVerticalGrowing = true
            chatTextView.customMinHeight = Layout.thumbnailWidth
            chatTextView.customCornerRadius = Layout.cornerRadius

            if caption != nil, isForwardingCaption {
                captionContentStack.axis = .vertical
                captionLabel.numberOfLines = 2
                captionContainerHeightConstraint.isActive = true
            }
        }

        chatTextView.invalidateIntrinsicContentSize()
        chatTextView.setNeedsLayout()
        chatTextView.layoutIfNeeded()

        setNeedsLayout()
        layoutIfNeeded()
    }

    private func updateToggleStackView() {
        let isLargeAccessibility = traitCollection.preferredContentSizeCategory > .accessibilityLarge
        toggleStackView.axis = isLargeAccessibility ? .vertical : .horizontal
        toggleStackView.alignment = isLargeAccessibility ? .leading : .center
        toggleStackView.sizeToFit()
    }

    private func updateCaptionText() {
        guard let caption else {
            return
        }

        captionLabel.attributedText = markupParser.previewString(
            for: caption,
            font: .preferredFont(forTextStyle: .caption1)
        )
    }

    private func makeCloseButtonImage() -> UIImage? {
        let pointSize = UIFont.preferredFont(forTextStyle: .caption1).pointSize
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        return UIImage(systemName: "xmark.circle.fill", withConfiguration: config)
    }

    private func setupTraitRegistration() {
        let traits: [UITrait] = [UITraitVerticalSizeClass.self, UITraitPreferredContentSizeCategory.self]
        registerForTraitChanges(traits) { [weak self] (_: Self, previous) in
            guard let self else {
                return
            }
            if previous.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
                updateContentForCurrentSizeCategory()
            }
            if previous.verticalSizeClass != traitCollection.verticalSizeClass {
                updateContentForCurrenSizeClass()
            }
        }
    }

    // MARK: - ObjC private methods

    @objc private func toggleSwitchValueChanged(_ sender: UISwitch) {
        onSendAsFileValueChanged?(sender.isOn)
    }

    @objc private func closeButtonTapped() {
        isForwardingCaption = false
        onForwardCaptionValueChanged?(isForwardingCaption)
        configureMessageStackView()
    }
}
