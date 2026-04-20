import Foundation

final class ReactionViewStackViewCountItemView: UIView, ReactionViewStackViewItemViewSubView {
    
    // MARK: - Properties

    var count: Int {
        didSet {
            updateView()
        }
    }
    
    // MARK: - Subviews
    
    private lazy var countLabel: UILabel = {
        let label = UILabel()
        
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .footnote)
            .addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: UIFont.Weight.semibold]])

        let semiboldFont = UIFont(descriptor: descriptor, size: 0)
    
        label.font = semiboldFont
        label.textColor = Colors.chatReactionBubbleTextColor
       
        label.translatesAutoresizingMaskIntoConstraints = false
        
        return label
    }()
    
    private lazy var countLabelConstraints: [NSLayoutConstraint] = [
        countLabel.topAnchor.constraint(greaterThanOrEqualTo: self.topAnchor),
        countLabel.bottomAnchor.constraint(lessThanOrEqualTo: self.bottomAnchor),
        countLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor),
        countLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor),
    ]
    
    // MARK: - Lifecycle
    
    init(count: Int) {
        self.count = count
        super.init(frame: .zero)
        configureView()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateView(type: ReactionViewStackViewItemView.ViewType) {
        switch type {
        case .reaction, .picker:
            return
        case let .count(count):
            self.count = count
        }
    }
    
    func updateColors() {
        countLabel.textColor = Colors.chatReactionBubbleTextColor
    }
    
    private func configureView() {
        isUserInteractionEnabled = false

        translatesAutoresizingMaskIntoConstraints = false
        addSubview(countLabel)
        
        NSLayoutConstraint.activate(countLabelConstraints)
        updateView()
    }
    
    private func updateView() {
        countLabel.text = "+\(count)"
    }
}
