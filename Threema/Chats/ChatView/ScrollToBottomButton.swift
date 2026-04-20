import Combine
import Foundation

@available(iOS 26.0, *)
class ScrollToBottomButton: UIButton {
   
    typealias Config = ChatViewConfiguration.ScrollToBottomButton

    private let unreadMessagesSnapshot: UnreadMessagesStateManager
    private var cancellables = Set<AnyCancellable>()
    
    private let processingQueue = DispatchQueue(label: "ch.threema.chatView.scrollToBottomView")

    // MARK: - Lifecycle
    
    init(
        unreadMessagesSnapshot: UnreadMessagesStateManager,
        scrollDownAction: @escaping (() -> Void)
    ) {
        self.unreadMessagesSnapshot = unreadMessagesSnapshot
        
        super.init(frame: .zero)
       
        // Config
        configure()
        
        // Action
        let action = UIAction { _ in
            scrollDownAction()
        }
        addAction(action, for: .touchUpInside)
        
        registerPublishers()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configure() {
        var configuration = UIButton.Configuration.glass()
       
        // Image
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
            pointSize: UIFontMetrics(forTextStyle: .body)
                .scaledValue(for: ChatBarConfiguration.defaultSize),
            weight: .regular,
            scale: .default
        )
        configuration.imagePadding = Config.glassButtonImageTextPadding
        configuration.imagePlacement = .all // needed to center image

        configuration.image = UIImage(systemName: "chevron.down")
       
        configuration.cornerStyle = .capsule
        
        // Text
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            let scaledValue = UIFontMetrics(forTextStyle: .body)
                .scaledValue(for: ChatBarConfiguration.defaultSize)
            outgoing.font = UIFont.monospacedDigitSystemFont(ofSize: scaledValue, weight: .regular)
            return outgoing
        }
        
        // We add a small additional inset to the top to make the image appear more centered
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: Config.glassButtonInsets + 1,
            leading: Config.glassButtonInsets,
            bottom: Config.glassButtonInsets,
            trailing: Config.glassButtonInsets
        )
        
        self.configuration = configuration
        
        // We hide it by default. Will get unhidden if needed by publishers below
        isHidden = true
    }
    
    // MARK: - Private functions
    
    private func registerPublishers() {
        unreadMessagesSnapshot.$unreadMessagesState
            .debounce(for: .milliseconds(Config.dataUpdateDebounce), scheduler: processingQueue)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] unreadMessagesState in
                guard let self, let unreadMessagesState else {
                    return
                }
                unreadMessageCountChanged(to: unreadMessagesState.numberOfUnreadMessages)
            }
            .store(in: &cancellables)

        unreadMessagesSnapshot.$userIsAtBottomOfTableView
            .debounce(for: .milliseconds(Config.dataUpdateDebounce), scheduler: processingQueue)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAtBottom in
                guard let self else {
                    return
                }
                userIsAtBottomOfTableViewChanged(to: isAtBottom)
            }
            .store(in: &cancellables)
    }
    
    private func unreadMessageCountChanged(to count: Int) {
        if count <= 0 {
            configuration?.title = nil
        }
        else {
            configuration?.title = "\(count)"
        }
    }
    
    private func userIsAtBottomOfTableViewChanged(to isAtBottom: Bool) {
        UIView.animate(withDuration: Config.ShowHideAnimation.duration) { [weak self] in
            self?.isHidden = isAtBottom
        }
    }
}
