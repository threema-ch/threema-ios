import SwiftUI
import UIKit

final class MessageForwardingBottomView: UIView {

    // MARK: - Private types

    private enum Layout {
        static let cornerRadius: CGFloat = 8.0
        static let topPadding: CGFloat = 8.0
        static let dividerHeight: CGFloat = 1.0 / UIScreen.main.scale

        static var horizontalInset: CGFloat {
            16.0 + cornerRadius / 2.0
        }
    }

    // MARK: - Internal properties

    var tipAnchorView: UIView?

    // MARK: - Private properties

    @Bindable private var model: MessageForwardingBottomViewModel

    lazy var dividerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .separator
        return view
    }()

    lazy var blurEffectView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .systemMaterial)
        let view = UIVisualEffectView(effect: effect)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - Lifecycle

    init(model: MessageForwardingBottomViewModel) {
        self.model = model
        super.init(frame: .zero)
        setupView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Private methods

    private func setupView() {
        setContentCompressionResistancePriority(.required, for: .vertical)
        setContentHuggingPriority(.required, for: .vertical)

        backgroundColor = .secondarySystemBackground

        let contentView = createContentView()
        layoutContentView(contentView)

        if #unavailable(iOS 26.0) {
            addSubview(blurEffectView)
            sendSubviewToBack(blurEffectView)

            NSLayoutConstraint.activate([
                blurEffectView.topAnchor.constraint(equalTo: topAnchor),
                blurEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
                blurEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
                blurEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
        }
    }

    private func createContentView() -> UIView {
        switch model.forwardType {
        case let .text(text):
            createTextMessageView(text: text)

        case let .data(symbol, description, thumbnail, caption):
            createFileMessageView(
                symbol: symbol,
                description: description,
                thumbnail: thumbnail,
                caption: caption
            )

        case let .location(symbol, description):
            createLocationMessageView(symbol: symbol, description: description)
        }
    }

    private func createTextMessageView(text: String) -> UIView {
        MessageForwardingTextMessageView(text: text, delegate: self)
    }

    private func createFileMessageView(
        symbol: String?,
        description: String,
        thumbnail: Data?,
        caption: String?
    ) -> UIView {
        let fileView = MessageForwardingFileMessageView(
            symbol: symbol,
            description: description,
            thumbnail: thumbnail,
            caption: caption,
            delegate: self
        )

        fileView.onSendAsFileValueChanged = { [weak self] value in
            self?.model.isSendingAsFile = value
        }

        fileView.onForwardCaptionValueChanged = { [weak self] value in
            self?.model.isForwardingCaption = value
        }

        tipAnchorView = fileView.getTipAnchorView()

        return fileView
    }

    private func createLocationMessageView(symbol: String?, description: String) -> UIView {
        MessageForwardingLocationMessageView(
            symbol: symbol,
            description: description,
            delegate: self
        )
    }

    private func layoutContentView(_ contentView: UIView) {
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)

        addSubview(contentView)
        addSubview(dividerView)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(
                equalTo: topAnchor,
                constant: Layout.topPadding
            ),
            contentView.leadingAnchor.constraint(
                equalTo: safeAreaLayoutGuide.leadingAnchor,
                constant: Layout.horizontalInset
            ),
            contentView.trailingAnchor.constraint(
                equalTo: safeAreaLayoutGuide.trailingAnchor,
                constant: -Layout.horizontalInset
            ),
            contentView.bottomAnchor.constraint(
                equalTo: keyboardLayoutGuide.topAnchor
            ),

            dividerView.topAnchor.constraint(equalTo: topAnchor),
            dividerView.heightAnchor.constraint(equalToConstant: Layout.dividerHeight),
            dividerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dividerView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }
}

// MARK: - ChatTextViewDelegate

extension MessageForwardingBottomView: ChatTextViewDelegate {
    func chatTextViewDidChange(_ textView: ChatTextView) {
        model.updateAdditionalText(textView.text)
    }

    func sendText() { }

    func canStartEditing() -> Bool { true }

    func didEndEditing() { }

    func checkIfPastedStringIsMedia() -> Bool { false }

    @available(iOS 18.0, *)
    func processAndSendGlyph(_ glyph: NSAdaptiveImageGlyph) { }

    func textView(
        _ textView: ChatTextView,
        primaryActionFor textItem: UITextItem,
        defaultAction: UIAction
    ) -> UIAction? {
        nil
    }

    func textView(
        _ textView: ChatTextView,
        editMenuFor textRange: UITextRange,
        suggestedActions: [UIMenuElement]
    ) -> UIMenu? {
        UIMenu(children: suggestedActions)
    }
}

// MARK: - Preview

#if DEBUG

    import ThreemaEssentials

    #Preview("Message Forwarding Input View") {
        UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
        return PreviewViewControllerRepresentable().ignoresSafeArea(.all)
    }

    struct PreviewViewControllerRepresentable: UIViewControllerRepresentable {

        func makeUIViewController(context: Context) -> PreviewViewController { PreviewViewController() }

        func updateUIViewController(_ uiViewController: PreviewViewController, context: Context) { }

        final class PreviewViewController: UIViewController {

            // MARK: - Private types

            private enum Layout {
                static let topOffset: CGFloat = 100
                static let horizontalPadding: CGFloat = 20
                static let buttonSpacing: CGFloat = 20
            }

            // MARK: - Private properties

            private var currentView: MessageForwardingBottomView?
            private let models = MessageForwardingPreviewHelper.makeViewModels()
            private var currentIndex = 0 {
                didSet { updateView() }
            }

            private let currentTitleLabel = UILabel()
            private let currentIndexLabel = UILabel()

            private lazy var prevButton = UIButton(
                configuration: .borderedTinted(),
                primaryAction: .init(title: "Previous") { [weak self] _ in
                    self?.navigateToPrevious()
                }
            )

            private lazy var nextButton = UIButton(
                configuration: .borderedTinted(),
                primaryAction: .init(title: "Next") { [weak self] _ in
                    self?.navigateToNext()
                }
            )

            // MARK: - Lifecycle

            init() {
                super.init(nibName: nil, bundle: nil)
                updateView()
            }

            @available(*, unavailable)
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }

            override func viewDidLoad() {
                super.viewDidLoad()
                setupView()
                setupNavigationControls()
            }

            // MARK: - Private methods

            private func setupView() {
                view.backgroundColor = .systemBackground
            }

            private func setupNavigationControls() {
                let navigationStack = createNavigationStack()

                for item in [navigationStack, currentTitleLabel] {
                    item.translatesAutoresizingMaskIntoConstraints = false
                    view.addSubview(item)
                }

                NSLayoutConstraint.activate([
                    navigationStack.topAnchor.constraint(
                        equalTo: view.topAnchor,
                        constant: Layout.topOffset
                    ),
                    navigationStack.leadingAnchor.constraint(
                        equalTo: view.leadingAnchor,
                        constant: Layout.horizontalPadding
                    ),
                    navigationStack.trailingAnchor.constraint(
                        equalTo: view.trailingAnchor,
                        constant: -Layout.horizontalPadding
                    ),

                    currentTitleLabel.topAnchor.constraint(
                        equalTo: navigationStack.bottomAnchor,
                        constant: Layout.buttonSpacing
                    ),
                    currentTitleLabel.leadingAnchor.constraint(
                        equalTo: view.leadingAnchor,
                        constant: Layout.horizontalPadding
                    ),
                    currentTitleLabel.trailingAnchor.constraint(
                        equalTo: view.trailingAnchor,
                        constant: -Layout.horizontalPadding
                    ),
                ])
            }

            private func createNavigationStack() -> UIStackView {
                let stack = UIStackView(arrangedSubviews: [prevButton, currentIndexLabel, nextButton])
                stack.axis = .horizontal
                stack.distribution = .fillEqually
                stack.spacing = Layout.buttonSpacing

                currentTitleLabel.numberOfLines = 0
                currentTitleLabel.textAlignment = .center
                currentTitleLabel.font = .preferredFont(forTextStyle: .footnote).bold()

                currentIndexLabel.textAlignment = .center
                currentIndexLabel.font = .preferredFont(forTextStyle: .title1).bold()

                return stack
            }

            private func navigateToPrevious() {
                guard currentIndex > 0 else {
                    return
                }
                currentIndex -= 1
            }

            private func navigateToNext() {
                guard currentIndex < models.count - 1 else {
                    return
                }
                currentIndex += 1
            }

            private func updateView() {
                currentView?.removeFromSuperview()

                let (title, model) = models[currentIndex]
                currentTitleLabel.text = title
                currentIndexLabel.text = "\(currentIndex + 1)/\(models.count)"

                let newView = MessageForwardingBottomView(model: model)
                newView.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(newView)

                NSLayoutConstraint.activate([
                    newView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    newView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                    newView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                ])

                newView.sizeToFit()
                view.layoutIfNeeded()
                currentView = newView
            }
        }
    }

    // MARK: - Preview helper

    enum MessageForwardingPreviewHelper {

        // MARK: - Types

        enum MessageType {
            case audio
            case video(hasThumbnail: Bool)
            case image(hasThumbnail: Bool)
            case file(hasThumbnail: Bool, mimeType: String?, caption: String?)
            case text(String)
            case location
        }

        // MARK: - Properties

        static let context = PreviewPersistence().context
        static let audioMimeType = UTIConverter.mimeType(fromUTI: UTType.mp3.identifier)
        static let imageMimeType = UTIConverter.mimeType(fromUTI: UTType.jpeg.identifier)
        static let videoMimeType = UTIConverter.mimeType(fromUTI: UTType.mpeg.identifier)

        static func makeUIImage() -> UIImage {
            UIImage(
                named: "PasscodeLogoOnprem",
                in: Bundle(for: MessageForwardingBottomView.self),
                with: nil
            )!
        }

        static func makeImageDataEntity() -> ImageDataEntity {
            let uiImage = makeUIImage()
            return ImageDataEntity(
                context: context,
                data: uiImage.pngData()!,
                height: Int16(uiImage.size.height),
                width: Int16(uiImage.size.width)
            )
        }

        @MainActor
        static func makeModel(_ type: MessageType) -> MessageForwardingBottomViewModel {
            try! MessageForwardingBottomViewModel(message: makeMessage(type))
        }

        static func makeMessage(_ type: MessageType) -> BaseMessageEntity {
            let conversation = ConversationEntity(context: context)

            switch type {
            case .audio:
                return AudioMessageEntity(
                    context: context,
                    id: BytesUtility.generateMessageID(),
                    isOwn: false,
                    conversation: conversation,
                    audio: nil
                )

            case let .image(hasThumbnail):
                return ImageMessageEntity(
                    context: context,
                    id: BytesUtility.generateMessageID(),
                    isOwn: false,
                    imageBlobID: BytesUtility.generateBlobID(),
                    image: makeImageDataEntity(),
                    thumbnail: hasThumbnail ? makeImageDataEntity() : nil,
                    conversation: conversation
                )

            case let .video(hasThumbnail):
                return VideoMessageEntity(
                    context: context,
                    id: BytesUtility.generateMessageID(),
                    isOwn: false,
                    conversation: conversation,
                    thumbnail: hasThumbnail ? makeImageDataEntity() : nil,
                    video: nil
                )

            case let .file(hasThumbnail, mimeType, caption):
                return FileMessageEntity(
                    context: context,
                    id: BytesUtility.generateMessageID(),
                    isOwn: false,
                    caption: caption,
                    mimeType: mimeType,
                    type: NSNumber(value: 1),
                    conversation: conversation,
                    thumbnail: hasThumbnail ? makeImageDataEntity() : nil,
                    data: nil
                )

            case let .text(text):
                return TextMessageEntity(
                    context: context,
                    id: BytesUtility.generateMessageID(),
                    isOwn: false,
                    text: text,
                    conversation: conversation
                )

            case .location:
                return LocationMessageEntity(
                    context: context,
                    id: BytesUtility.generateMessageID(),
                    isOwn: false,
                    accuracy: 12.5,
                    latitude: 47.3769,
                    longitude: 8.5417,
                    poiAddress: "Street Address 123",
                    poiName: "The International Museum of Ancient Aeronautical & Maritime Antiquities",
                    conversation: conversation
                )
            }
        }

        @MainActor
        static func makeViewModels() -> [(String, MessageForwardingBottomViewModel)] {
            [
                ("TextMessageEntity \n[short content]", makeModel(.text("Hello _italic_ and *bold* text."))),

                ("TextMessageEntity \n[long content]", makeModel(.text("""
                    Lorem ipsum _dolor_ sit amet *consectetur* adipiscing elit. Quisque faucibus
                    sapien vitae ~pellentesque~ sem placerat. In id cursus mi pretium tellus duis
                    convallis. Tempus leo eu aenean sed diam urna tempor. Pulvinar vivamus
                    fringilla lacus nec metus bibendum egestas. Iaculis massa nisl malesuada
                    lacinia integer nunc posuere. Ut hendrerit semper vel class aptent taciti
                    sociosqu. Ad litora torquent per conubia nostra inceptos himenaeos.
                    """))),

                ("LocationMessageEntity \n[Address]", makeModel(.location)),

                ("AudioMessageEntity \n[legacy format]", makeModel(.audio)),

                ("ImageMessageEntity \n[legacy format] \n[no thumbnail]", makeModel(.image(hasThumbnail: false))),

                ("ImageMessageEntity \n[legacy format] \n[with thumbnail]", makeModel(.image(hasThumbnail: true))),

                ("VideoMessageEntity \n[legacy format] \n[no thumbnail]", makeModel(.video(hasThumbnail: false))),

                ("VideoMessageEntity \n[legacy format] \n[with thumbnail]", makeModel(.video(hasThumbnail: true))),

                (
                    "FileMessageEntity \n[audio data] \n[no thumbnail] \n[no caption]",
                    makeModel(.file(hasThumbnail: false, mimeType: audioMimeType, caption: nil))
                ),

                (
                    "FileMessageEntity \n[audio data] \n[with thumbnail] \n[no caption]",
                    makeModel(.file(hasThumbnail: true, mimeType: audioMimeType, caption: nil))
                ),

                (
                    "FileMessageEntity \n[audio data] \n[with thumbnail] \n[with caption]",
                    makeModel(
                        .file(hasThumbnail: true, mimeType: audioMimeType, caption: "Hello _italic_ and *bold* text.")
                    )
                ),

                (
                    "FileMessageEntity \n[image data] \n[no thumbnail] \n[no caption]",
                    makeModel(.file(hasThumbnail: false, mimeType: imageMimeType, caption: nil))
                ),

                (
                    "FileMessageEntity \n[image data] \n[with thumbnail] \n[no caption]",
                    makeModel(.file(hasThumbnail: true, mimeType: imageMimeType, caption: nil))
                ),

                (
                    "FileMessageEntity \n[image data] \n[with thumbnail] \n[with caption]",
                    makeModel(
                        .file(hasThumbnail: true, mimeType: imageMimeType, caption: "Hello _italic_ and *bold* text.")
                    )
                ),

                (
                    "FileMessageEntity \n[video data] \n[no thumbnail] \n[no caption]",
                    makeModel(.file(hasThumbnail: false, mimeType: videoMimeType, caption: nil))
                ),

                (
                    "FileMessageEntity \n[video data] \n[with thumbnail] \n[no caption]",
                    makeModel(.file(hasThumbnail: true, mimeType: videoMimeType, caption: nil))
                ),

                (
                    "FileMessageEntity \n[video data] \n[with thumbnail] \n[with caption]",
                    makeModel(
                        .file(hasThumbnail: true, mimeType: videoMimeType, caption: "Hello _italic_ and *bold* text.")
                    )
                ),

                (
                    "FileMessageData \n[other data] \n[no thumbnail] \n[no caption]",
                    makeModel(.file(
                        hasThumbnail: false,
                        mimeType: UTIConverter.mimeType(fromUTI: UTType.pdf.identifier),
                        caption: nil
                    ))
                ),

                (
                    "FileMessageData \n[other data] \n[with thumbnail] \n[no caption]",
                    makeModel(.file(
                        hasThumbnail: true,
                        mimeType: UTIConverter.mimeType(fromUTI: UTType.pdf.identifier),
                        caption: nil
                    ))
                ),

                (
                    "FileMessageData \n[other data] \n[with thumbnail] \n[with caption]",
                    makeModel(.file(
                        hasThumbnail: true,
                        mimeType: UTIConverter.mimeType(fromUTI: UTType.pdf.identifier),
                        caption: "Hello _italic_ and *bold* text."
                    ))
                ),
            ]
        }
    }

#endif
