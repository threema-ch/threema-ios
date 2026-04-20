import ThreemaMacros
import UIKit

final class MessageForwardingTextMessageView: UIStackView {

    // MARK: - Private Types

    private enum Layout {
        static let cornerRadius: CGFloat = 8.0
        static let barWidth: CGFloat = 2.0
        static let barCornerRadius: CGFloat = 1.0
        static let spacing: CGFloat = 8.0

        enum MessageContainer {
            static let top: CGFloat = 6.0
            static let bottom: CGFloat = 6.0
            static let leading: CGFloat = 18.0
            static let trailing: CGFloat = 8.0
            static let labelSpacing: CGFloat = 4.0
            static let barOffset: CGFloat = 2.0
        }
    }

    // MARK: - Private properties

    private weak var delegate: (any ChatTextViewDelegate)?
    private let markupParser = MarkupParser()
    private let text: String

    private lazy var barView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemGray
        view.layer.cornerRadius = Layout.barCornerRadius
        view.layer.masksToBounds = true

        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: Layout.barWidth),
        ])

        return view
    }()

    private lazy var chatTextView: ChatTextView = {
        let view = ChatTextView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBackground
        view.chatTextViewDelegate = delegate
        view.placeholderVerticalPosition = .center
        view.placeholderTextValue = #localize("message_forwarding_input_placeholder")
        return view
    }()

    private lazy var headerLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .body).bold()
        label.adjustsFontForContentSizeCategory = true
        label.text = #localize("message_forwarding_input_heading")
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()

    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 4
        label.lineBreakMode = .byTruncatingTail
        label.textColor = .label
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }()

    private lazy var messageContainerView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [headerLabel, messageLabel])
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = Layout.MessageContainer.labelSpacing
        stackView.backgroundColor = .tertiarySystemFill
        stackView.layer.cornerRadius = Layout.cornerRadius
        stackView.layer.masksToBounds = true
        stackView.setContentCompressionResistancePriority(.required, for: .vertical)

        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: Layout.MessageContainer.top,
            leading: Layout.MessageContainer.leading,
            bottom: Layout.MessageContainer.bottom,
            trailing: Layout.MessageContainer.trailing
        )

        stackView.addSubview(barView)
        NSLayoutConstraint.activate([
            barView.topAnchor.constraint(
                equalTo: stackView.topAnchor,
                constant: Layout.MessageContainer.top + Layout.MessageContainer.barOffset
            ),
            barView.bottomAnchor.constraint(
                equalTo: stackView.bottomAnchor,
                constant: -(Layout.MessageContainer.bottom + Layout.MessageContainer.barOffset)
            ),
            barView.leadingAnchor.constraint(
                equalTo: stackView.leadingAnchor,
                constant: Layout.MessageContainer.leading / 2.0
            ),
        ])

        return stackView
    }()

    // MARK: - Lifecycle

    init(text: String, delegate: any ChatTextViewDelegate) {
        self.text = text
        self.delegate = delegate

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

    // MARK: - Private methods

    private func configureStackView() {
        axis = .vertical
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
        addArrangedSubview(messageContainerView)
        addArrangedSubview(chatTextView)
    }

    private func updateContentForCurrentSizeCategory() {
        messageLabel.attributedText = markupParser.previewString(
            for: text,
            font: .preferredFont(forTextStyle: .body)
        )
    }

    private func updateContentForCurrenSizeClass() {
        let hasCompactVerticalSizeClass = traitCollection.verticalSizeClass == .compact
        if hasCompactVerticalSizeClass {
            messageContainerView.axis = .horizontal
            headerLabel.numberOfLines = 1
            messageLabel.numberOfLines = 1
            chatTextView.allowsVerticalGrowing = false
        }
        else {
            messageContainerView.axis = .vertical
            headerLabel.numberOfLines = 0
            messageLabel.numberOfLines = 4
            chatTextView.allowsVerticalGrowing = true
        }

        chatTextView.invalidateIntrinsicContentSize()
        chatTextView.layoutIfNeeded()

        setNeedsLayout()
        layoutIfNeeded()
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
}
