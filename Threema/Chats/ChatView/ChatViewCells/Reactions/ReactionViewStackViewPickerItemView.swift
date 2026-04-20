import Foundation

final class ReactionViewStackViewPickerItemView: UIView, ReactionViewStackViewItemViewSubView {
        
    // MARK: - Subviews
        
    private lazy var imageView: UIImageView = {
        let config = UIImage.SymbolConfiguration(font: UIFont.preferredFont(forTextStyle: .body))
        
        let image = UIImage(resource: .threemaCustomFaceSmilingBadgePlus)
         
        let imageView = UIImageView(image: image)
        imageView.preferredSymbolConfiguration = config
        imageView.tintColor = Colors.chatReactionBubbleTextColor
        imageView.contentMode = .scaleAspectFit
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        return imageView
    }()
    
    private lazy var imageViewConstraints: [NSLayoutConstraint] = [
        imageView.topAnchor.constraint(greaterThanOrEqualTo: self.topAnchor),
        imageView.bottomAnchor.constraint(lessThanOrEqualTo: self.bottomAnchor),
        imageView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
        imageView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
    ]
    
    // MARK: - Lifecycle
    
    init() {
        super.init(frame: .zero)
        configureView()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateView(type: ReactionViewStackViewItemView.ViewType) {
        // No-op
    }
    
    func updateColors() {
        imageView.tintColor = Colors.chatReactionBubbleTextColor
    }
    
    private func configureView() {
        isUserInteractionEnabled = false

        translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        
        NSLayoutConstraint.activate(imageViewConstraints)
    }
}
