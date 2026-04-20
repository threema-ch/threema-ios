import CocoaLumberjackSwift
import ThreemaFramework
import ThreemaMacros
import UIKit

protocol ChatBarEditedMessageViewDelegate: AnyObject {
    /// Handle dismissal of the edit message view. The edit message view will not remove itself from the view hierarchy.
    func editedMessageDismissed()
    /// The text inset from the left edge of the screen to allow alignment of accessory views
    var editedMessageTextBeginningInset: CGFloat { get }
}

final class ChatBarEditedMessageView: UIView {
    // MARK: - Nested Types

    private typealias Config = ChatBarConfiguration.QuoteView
    
    // MARK: - Private Properties

    private let editedMessage: EditedMessage
    private weak var delegate: ChatBarEditedMessageViewDelegate?

    private lazy var editedMessageView: MessageEditedMessageStackView = {
        let messageEditedMessageView = MessageEditedMessageStackView()
        messageEditedMessageView.editedMessage = editedMessage
        messageEditedMessageView.thumbnailDistribution = .spaced
        
        messageEditedMessageView.translatesAutoresizingMaskIntoConstraints = false
        messageEditedMessageView.isAccessibilityElement = true
        
        return messageEditedMessageView
    }()
    
    private lazy var closeEditMessageButton: ChatBarButton = {
        let action = UIAction { [weak self] _ in
            self?.delegate?.editedMessageDismissed()
        }
        
        let button = ChatBarButton(
            for: .closeEditButton,
            action: action
        )
        
        button.configuration?.contentInsets = .zero
        button.accessibilityHint = #localize(
            "accessibility_chatbar_close_edited_message_button_hint"
        )

        return button
    }()

    private lazy var contentStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [editedMessageView, closeEditMessageButton])
        stackView.axis = .horizontal
        stackView.distribution = .equalSpacing
        stackView.alignment = .center
        stackView.spacing = Config.stackViewSpacing
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        return stackView
    }()
    
    private lazy var leadingConstraint: NSLayoutConstraint = {
        let leftInset =
            if #available(iOS 26.0, *) {
                Config.leadingTrailingInset
            }
            else {
                delegate?.editedMessageTextBeginningInset ?? Config.leadingTrailingInset
            }
        return leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: -leftInset)
    }()
    
    // MARK: - Lifecycle

    init(editedMessage: EditedMessage, delegate: ChatBarEditedMessageViewDelegate) {
        self.editedMessage = editedMessage
        self.delegate = delegate
        
        super.init(frame: .zero)
        
        configureLayout()
        updateColors()
        updateAccessibility()
        
        self.contentMode = .redraw
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Configuration Functions

    private func updateColors() {
        editedMessageView.updateColors()
        backgroundColor = .clear
    }
    
    private func configureLayout() {
        addSubview(contentStackView)
        
        if #available(iOS 26, *) {
            contentStackView.isLayoutMarginsRelativeArrangement = true
            contentStackView.layoutMargins = .init(
                top: Config.glassLayoutMargins,
                left: Config.glassLayoutMargins,
                bottom: Config.glassLayoutMargins,
                right: Config.glassLayoutMargins
            )
        }
        
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: contentStackView.topAnchor, constant: -Config.topBottomInset),
            leadingConstraint,
            bottomAnchor.constraint(equalTo: contentStackView.bottomAnchor, constant: Config.topBottomInset),
            safeAreaLayoutGuide.trailingAnchor.constraint(
                equalTo: contentStackView.trailingAnchor,
                constant: Config.leadingTrailingInset
            ),
        ])
    }
    
    private func updateAccessibility() {
        guard let message = editedMessage as? MessageAccessibility else {
            return
        }
        editedMessageView.accessibilityLabel = String.localizedStringWithFormat(
            #localize("accessibility_chatbar_edited_message_label"),
            message.accessibilitySenderAndMessageTypeText
        )
    }
    
    // MARK: - Update Functions

    private func reconfigureLayout() {
        let leftInset =
            if #available(iOS 26.0, *) {
                Config.leadingTrailingInset
            }
            else {
                delegate?.editedMessageTextBeginningInset ?? Config.leadingTrailingInset
            }
        
        leadingConstraint.constant = -leftInset
    }
    
    // MARK: - Overrides

    override func layoutSubviews() {
        super.layoutSubviews()
        reconfigureLayout()
    }
}
