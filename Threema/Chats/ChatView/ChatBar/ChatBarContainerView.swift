import CocoaLumberjackSwift
import ThreemaFramework
import UIKit

/// Contains the chatbar and any accessory views related to the chatbar
final class ChatBarContainerView: UIView {
    
    // MARK: - Properties
    
    /// Blur effect for chat bar background
    /// Is only internal to allow a workaround for iPads with external keyboards
    /// See `configureLayout` of `ChatViewController` for more details
    lazy var blurEffectView: UIVisualEffectView = {
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        return blurEffectView
    }()
    
    // MARK: - Private properties
    
    private weak var chatBarView: ChatBarView?
    
    private weak var editedMessageView: ChatBarEditedMessageView?
    private weak var quoteView: ChatBarQuoteView?
    private weak var mentionsTableView: MentionsTableViewController?
    
    private var catchTapOnDisabledView: UIView?
    
    private lazy var accessoryView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        
        return stackView
    }()
    
    private lazy var glassAccessoryView: UIView = {
        guard #available(iOS 26.0, *) else {
            return UIView()
        }
      
        let glassEffect = UIGlassEffect(style: .regular)
        
        let glassEffectView = UIVisualEffectView(effect: glassEffect)
        glassEffectView.contentView.addSubview(accessoryView)
        
        accessoryView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            accessoryView.topAnchor.constraint(
                equalTo: glassEffectView.contentView.topAnchor
            ),
            accessoryView.trailingAnchor.constraint(
                equalTo: glassEffectView.contentView.trailingAnchor
            ),
            accessoryView.leadingAnchor.constraint(
                equalTo: glassEffectView.contentView.leadingAnchor
            ),
            accessoryView.bottomAnchor.constraint(
                equalTo: glassEffectView.contentView.bottomAnchor
            ),
        ])
        
        glassEffectView.cornerConfiguration = .uniformCorners(
            radius: UICornerRadius(floatLiteral: ChatTextViewConfiguration.cornerRadius)
        )

        return glassEffectView
    }()
    
    private lazy var topHairlineView: UIView = {
        let view = UIView()
        view.backgroundColor = .separator
        return view
    }()

    private var mentionsTableViewHeightConstraint: NSLayoutConstraint?
    
    // MARK: Lifecycle
    
    init() {
        super.init(frame: .zero)
        // Due to having different constraints, the configuration for glass happens only after the chat bar was added.
        if #unavailable(iOS 26.0) {
            configureOldLayout()
            // This should give an effect similar to the one in the tab bar
            backgroundColor = .tertiarySystemBackground
        }
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Configuration

    private func configureGlassLayout() {
        translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(glassAccessoryView)
        glassAccessoryView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            glassAccessoryView.topAnchor.constraint(equalTo: topAnchor),
            glassAccessoryView.leadingAnchor.constraint(
                equalTo: chatBarView!.glassEffectChatTextView.leadingAnchor
            ),
            glassAccessoryView.trailingAnchor.constraint(
                equalTo: chatBarView!.sendButton.leadingAnchor,
                constant: -ChatBarConfiguration.textInputButtonSpacing
            ),
        ])
    }
    
    private func configureOldLayout() {
        translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(accessoryView)
        accessoryView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            accessoryView.topAnchor.constraint(equalTo: topAnchor),
            accessoryView.leadingAnchor.constraint(equalTo: leadingAnchor),
            accessoryView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        
        topHairlineView.translatesAutoresizingMaskIntoConstraints = false
        accessoryView.addArrangedSubview(topHairlineView)
        NSLayoutConstraint.activate([
            topHairlineView.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
        ])
        
        addSubview(blurEffectView)
        sendSubviewToBack(blurEffectView)
        blurEffectView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            blurEffectView.topAnchor.constraint(equalTo: topAnchor),
            blurEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        
        if traitCollection.horizontalSizeClass == .compact {
            // See the definition of `blurEffectView` for more information.
            let window = UIApplication.shared.windows.first
            let bottomPadding = window?.safeAreaInsets.bottom ?? 0
            
            NSLayoutConstraint.activate([
                blurEffectView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: bottomPadding),
            ])
        }
    }

    // MARK: Updates
    
    /// Updates the ChatBarContainerView instance with this chatBarView
    /// - Parameter chatBarView:
    func add(_ chatBarView: ChatBarView) {
        guard chatBarView != self.chatBarView else {
            return
        }
        
        if self.chatBarView != nil {
            removeChatBarView()
        }
        
        self.chatBarView = chatBarView
        
        addSubview(chatBarView)
        chatBarView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            chatBarView.leadingAnchor.constraint(equalTo: leadingAnchor),
            chatBarView.bottomAnchor.constraint(equalTo: bottomAnchor),
            chatBarView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        
        if #available(iOS 26.0, *) {
            configureGlassLayout()
            
            NSLayoutConstraint.activate([
                chatBarView.topAnchor.constraint(
                    equalTo: glassAccessoryView.bottomAnchor,
                    constant: ChatBarConfiguration.verticalChatBarTextViewDistance
                ),
            ])
        }
        else {
            NSLayoutConstraint.activate([
                chatBarView.topAnchor.constraint(equalTo: accessoryView.bottomAnchor),
            ])
        }
        
        layoutIfNeeded()
    }
    
    /// Removes the currently set ChatBarView instance from this container
    func removeChatBarView() {
        chatBarView?.removeFromSuperview()
        chatBarView = nil
        
        layoutIfNeeded()
    }
    
    func add(_ mentionsTableViewController: MentionsTableViewController) {
        guard mentionsTableViewController != mentionsTableView else {
            return
        }
        
        if mentionsTableView != nil {
            removeMentionsTableView()
        }
        
        mentionsTableView = mentionsTableViewController
        
        accessoryView.insertArrangedSubview(mentionsTableViewController.view, at: 0)
        
        mentionsTableViewController.view.translatesAutoresizingMaskIntoConstraints = false
        
        updateMentionsTableViewHeight()
        
        layoutIfNeeded()
    }
    
    func removeMentionsTableView() {
        updateMentionsTableViewHeight(overwriteHeight: 0.0) { _ in
            self.mentionsTableView?.view.removeFromSuperview()
            self.mentionsTableView = nil
        }
    }
    
    func add(_ editedMessageView: ChatBarEditedMessageView) {
        guard self.editedMessageView != editedMessageView else {
            return
        }

        if self.editedMessageView != nil {
            removeEditedMessageView()
        }

        self.editedMessageView = editedMessageView

        accessoryView.insertArrangedSubview(editedMessageView, at: accessoryView.arrangedSubviews.count)
        accessoryView.bringSubviewToFront(editedMessageView)

        editedMessageView.translatesAutoresizingMaskIntoConstraints = false

        layoutIfNeeded()
    }

    func removeEditedMessageView() {
        editedMessageView?.removeFromSuperview()
        editedMessageView = nil
        layoutIfNeeded()
    }

    func add(_ quoteView: ChatBarQuoteView) {
        guard self.quoteView != quoteView else {
            return
        }
        
        if self.quoteView != nil {
            removeQuoteView()
        }
        
        self.quoteView = quoteView
        
        accessoryView.insertArrangedSubview(quoteView, at: accessoryView.arrangedSubviews.count)
        accessoryView.bringSubviewToFront(quoteView)
        
        quoteView.translatesAutoresizingMaskIntoConstraints = false
        
        layoutIfNeeded()
    }
    
    func removeQuoteView() {
        quoteView?.removeFromSuperview()
        quoteView = nil
        layoutIfNeeded()
    }
    
    /// Disables interaction with any view shown by the ContainerView by adding a view on top of it
    /// - Parameter newCatchTapOnDisabledView: The view used to lay over everything else in the ContainerView
    func disableInteraction(with newCatchTapOnDisabledView: UIView) {
        guard catchTapOnDisabledView != newCatchTapOnDisabledView else {
            return
        }
        
        if catchTapOnDisabledView != nil {
            enableInteraction()
        }
        
        catchTapOnDisabledView = newCatchTapOnDisabledView
        
        guard let catchTapOnDisabledView else {
            return
        }
        
        addSubview(catchTapOnDisabledView)
        bringSubviewToFront(catchTapOnDisabledView)
        
        NSLayoutConstraint.activate([
            catchTapOnDisabledView.topAnchor.constraint(equalTo: topAnchor),
            catchTapOnDisabledView.leadingAnchor.constraint(equalTo: leadingAnchor),
            catchTapOnDisabledView.bottomAnchor.constraint(equalTo: bottomAnchor),
            catchTapOnDisabledView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }
    
    /// Remove any views added with disableInteraction
    func enableInteraction() {
        catchTapOnDisabledView?.removeFromSuperview()
    }
        
    // MARK: Updates for Coordinator
    
    func updateMentionsTableViewHeight(overwriteHeight: CGFloat? = nil, onCompletion: ((Bool) -> Void)? = nil) {
        guard let mentionsTableView else {
            DDLogError("Should not call updateMentionsTableViewHeight without mentionsTableView")
            return
        }
        
        layoutIfNeeded()
        
        let maxHeight: CGFloat = overwriteHeight ?? min(
            ChatViewConfiguration.MentionsView.maxHeight,
            Double(mentionsTableView.tableView.contentSize.height)
        )
        
        mentionsTableViewHeightConstraint?.isActive = false
        mentionsTableViewHeightConstraint = mentionsTableView.view.heightAnchor
            .constraint(equalToConstant: maxHeight)
        mentionsTableViewHeightConstraint?.isActive = true
        mentionsTableView.tableView.isHidden = true
        
        UIView.animate(
            withDuration: ChatBarConfiguration.ContentInsetAnimation.totalDuration,
            delay: ChatBarConfiguration.ContentInsetAnimation.delay,
            options: .curveEaseInOut,
            animations: { [weak self] in
                mentionsTableView.tableView.isHidden = false
                self?.layoutIfNeeded()
            },
            completion: onCompletion
        )
    }
    
    @discardableResult override func becomeFirstResponder() -> Bool {
        chatBarView?.becomeFirstResponder() ?? false
    }
    
    override func resignFirstResponder() -> Bool {
        guard let chatBarView else {
            return false
        }
        return chatBarView.resignFirstResponder()
    }
}
