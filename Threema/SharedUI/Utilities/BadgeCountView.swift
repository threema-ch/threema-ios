import Foundation

final class BadgeCountView: UIView {
    
    // MARK: Views
    
    private lazy var badgeLabel = BadgeCountLabel()
    
    // MARK: - Lifecycle
    
    /// Create a badge view
    init() {
        super.init(frame: .zero)
        
        configureView()
        updateCountLabel(to: "")
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Configuration
    
    private func configureView() {
        
        translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(badgeLabel)

        NSLayoutConstraint.activate([
            badgeLabel.topAnchor.constraint(equalTo: topAnchor),
            badgeLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            badgeLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            badgeLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
            badgeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            badgeLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }
    
    public func updateColors() {
        badgeLabel.updateColors()
    }
        
    // MARK: - Updates
    
    /// Update count label
    /// - Parameter countString: String with the new count
    func updateCountLabel(to countString: String) {
        badgeLabel.text = countString
    }
}
