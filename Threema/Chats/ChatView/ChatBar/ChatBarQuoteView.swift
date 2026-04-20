import CocoaLumberjackSwift
import ThreemaFramework
import ThreemaMacros
import UIKit

protocol ChatBarQuoteViewDelegate: AnyObject {
    /// Handle dismissal of the quote view. The quote view will not remove itself from the view hierarchy.
    func quoteDismissed()
    /// The text inset from the left edge of the screen to allow alignment of accessory views
    var textBeginningInset: CGFloat { get }
}

final class ChatBarQuoteView: UIView {
    // MARK: - Nested Types

    private typealias Config = ChatBarConfiguration.QuoteView
    
    // MARK: - Private Properties

    private let quotedMessage: QuoteMessage
    private weak var delegate: ChatBarQuoteViewDelegate?
    
    private lazy var quoteView: MessageQuoteStackView = {
        let messageQuoteView = MessageQuoteStackView()
        messageQuoteView.quoteMessage = quotedMessage
        messageQuoteView.thumbnailDistribution = .spaced
        messageQuoteView.placement = .ChatBar
        
        messageQuoteView.translatesAutoresizingMaskIntoConstraints = false
        messageQuoteView.isAccessibilityElement = true
        
        return messageQuoteView
    }()
    
    private lazy var closeQuoteButton: ChatBarButton = {
        let action = UIAction { [weak self] _ in
            self?.delegate?.quoteDismissed()
        }
        let button = ChatBarButton(
            for: .closeQuoteButton,
            action: action
        )
        
        button.configuration?.contentInsets = .zero
        button.accessibilityHint = #localize("accessibility_chatbar_close_quote_button_hint")
        
        return button
    }()

    private lazy var contentStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [quoteView, closeQuoteButton])
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
                delegate?.textBeginningInset ?? Config.leadingTrailingInset
            }
        return leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: -leftInset)
    }()
    
    // MARK: - Lifecycle

    init(quotedMessage: QuoteMessage, delegate: ChatBarQuoteViewDelegate) {
        self.quotedMessage = quotedMessage
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
        quoteView.updateColors()
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
        guard let message = quotedMessage as? MessageAccessibility else {
            return
        }
        quoteView.accessibilityLabel = String.localizedStringWithFormat(
            #localize("accessibility_chatbar_quote_label"),
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
                delegate?.textBeginningInset ?? Config.leadingTrailingInset
            }
        
        leadingConstraint.constant = -leftInset
    }
    
    // MARK: - Overrides

    override func layoutSubviews() {
        super.layoutSubviews()
        reconfigureLayout()
    }
}
