import Foundation

class BadgeCountLabel: UILabel {
    
    override var intrinsicContentSize: CGSize {
        var contentSize = super.intrinsicContentSize
        contentSize.height = 20
        
        if contentSize.width < 20 {
            contentSize.width = 20
        }
        else if contentSize.width > 20 {
            contentSize.width += 10
        }
        
        return contentSize
    }

    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLabel()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLabel()
    }
    
    convenience init() {
        self.init(frame: .zero)
    }
    
    override func drawText(in rect: CGRect) {
        let insets = UIEdgeInsets.zero
        super.drawText(in: rect.inset(by: insets))
    }
    
    public func updateColors() {
        backgroundColor = .systemRed
        textColor = .white
        highlightedTextColor = .white
    }
    
    private func configureLabel() {
        font = UIFont.systemFont(ofSize: 13)
        updateColors()
        
        numberOfLines = 1
        textAlignment = .center
        translatesAutoresizingMaskIntoConstraints = false
        adjustsFontForContentSizeCategory = false
        
        layer.masksToBounds = true
        layer.cornerCurve = .continuous
        layer.cornerRadius = 10
    }
}
