import Foundation

protocol ReactionViewStackViewItemViewSubView: UIView {
    func updateView(type: ReactionViewStackViewItemView.ViewType)
    func updateColors()
}

final class ReactionViewStackViewItemView: UIView {
    typealias config = ChatViewConfiguration.EmojiReactions.CellStackView

    enum ViewType: Equatable {
        case reaction(info: ReactionsManager.ReactionInfo)
        case count(count: Int)
        case picker
    }
    
    // MARK: - Properties

    var type: ViewType {
        didSet {
            subview.updateView(type: type)
            updateColors()
        }
    }
    
    private let reactionsManager: ReactionsManager

    // MARK: - Subviews
    
    private let topBottomBubbleInset = config.itemTopBottomInset
    private let leadingTrailingBubbleInset = config.itemLeadingTrailingInset
    
    private lazy var button: UIButton = {
        let configuration = UIButton.Configuration.plain()
        let action = UIAction { [weak self] _ in
            guard let self else {
                return
            }
            
            switch type {
            case let .reaction(info):
                reactionsManager.send(info.emoji)
            case let .count(count):
                reactionsManager.showExistingReactions()
                return
            case .picker:
                reactionsManager.showEmojiPickerSheet()
            }
            
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        
        let button = UIButton(configuration: configuration, primaryAction: action)
        
        button.configurationUpdateHandler = { [weak self] button in
            guard let self else {
                return
            }
            
            if button.state == .highlighted {
                backgroundColor = Colors.chatReactionBubbleHighlighted
            }
            else {
                switch type {
                case let .reaction(info):
                    backgroundColor = reactionsManager.isCurrentlySelected(emoji: info.emoji) ? Colors
                        .chatReactionBubbleSelected : Colors.chatReactionBubble
                case .count, .picker:
                    backgroundColor = Colors.chatReactionBubble
                }
            }
        }
        
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var buttonConstraints: [NSLayoutConstraint] = [
        button.topAnchor.constraint(equalTo: self.topAnchor),
        button.bottomAnchor.constraint(equalTo: self.bottomAnchor),
        button.leadingAnchor.constraint(equalTo: self.leadingAnchor),
        button.trailingAnchor.constraint(equalTo: self.trailingAnchor),
        button.widthAnchor.constraint(greaterThanOrEqualTo: button.heightAnchor),
    ]
    
    private lazy var subview: ReactionViewStackViewItemViewSubView =
        switch type {
        case let .reaction(info):
            ReactionViewStackViewReactionItemView(info: info)
        case let .count(count):
            ReactionViewStackViewCountItemView(count: count)
        case .picker:
            ReactionViewStackViewPickerItemView()
        }
    
    private lazy var subViewConstraints: [NSLayoutConstraint] = [
        subview.topAnchor.constraint(greaterThanOrEqualTo: button.topAnchor, constant: topBottomBubbleInset),
        subview.bottomAnchor.constraint(greaterThanOrEqualTo: button.bottomAnchor, constant: -topBottomBubbleInset),
        subview.leadingAnchor.constraint(
            greaterThanOrEqualTo: button.leadingAnchor,
            constant: leadingTrailingBubbleInset
        ),
        subview.trailingAnchor.constraint(
            greaterThanOrEqualTo: button.trailingAnchor,
            constant: -leadingTrailingBubbleInset
        ),
        subview.centerXAnchor.constraint(equalTo: button.centerXAnchor),
        subview.centerYAnchor.constraint(equalTo: button.centerYAnchor),
        subview.widthAnchor.constraint(greaterThanOrEqualToConstant: config.itemMinWidth),
    ]
    
    // MARK: - Lifecycle
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }
    
    init(reactionsManager: ReactionsManager, type: ViewType) {
        self.reactionsManager = reactionsManager
        self.type = type
        
        super.init(frame: .zero)
        
        configureView()
        setupTraitRegistration()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configureView() {
        addSubview(button)
        NSLayoutConstraint.activate(buttonConstraints)
        
        button.addSubview(subview)
        NSLayoutConstraint.activate(subViewConstraints)

        setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        layer.borderWidth = config.itemBorderWidth
        layer.masksToBounds = true

        if case .reaction = type {
            isHidden = true
            alpha = 0.0
        }
        
        updateColors()
    }
    
    public func updateColors() {
        layer.borderColor = Colors.chatReactionBubbleBorder.resolvedColor(with: traitCollection).cgColor
        
        switch type {
        case let .reaction(info):
            backgroundColor = reactionsManager.isCurrentlySelected(emoji: info.emoji) ? Colors
                .chatReactionBubbleSelected : Colors.chatReactionBubble
        case .count, .picker:
            backgroundColor = Colors.chatReactionBubble
        }
        
        subview.updateColors()
    }

    private func setupTraitRegistration() {
        let traits: [UITrait] = [UITraitUserInterfaceStyle.self]
        registerForTraitChanges(traits) { [weak self] (_: Self, previous) in
            guard let self else {
                return
            }
            if previous.userInterfaceStyle != traitCollection.userInterfaceStyle {
                updateColors()
            }
        }
    }
}
