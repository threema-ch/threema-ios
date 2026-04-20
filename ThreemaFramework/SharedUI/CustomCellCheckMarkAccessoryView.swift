final class CustomCellCheckMarkAccessoryView: UIView {
    
    // MARK: - Public properties
    
    var isChecked = false {
        didSet { updateImage() }
    }

    // MARK: - Private properties
    
    private var imageName: String { isChecked ? "checkmark.circle.fill" : "circle" }
    private var paletteColors: [UIColor] { isChecked ? [.white, .tintColor] : [.systemGray2] }

    private var image: UIImage? {
        let config = UIImage.SymbolConfiguration(scale: .large)
        return UIImage(systemName: imageName)?.applying(configuration: config, paletteColors: paletteColors)
    }

    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = image
        imageView.contentMode = .scaleAspectFill
        imageView.tintColor = .tintColor
        return imageView
    }()
    
    // MARK: - Lifecycle

    init() {
        super.init(frame: .zero)
        
        setupView()
        setupDynamicTypeObserver()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Configuration

    private func setupView() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        imageView.setContentHuggingPriority(.required, for: .vertical)
        imageView.setContentCompressionResistancePriority(.required, for: .vertical)
        
        addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func setupDynamicTypeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateImage),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
    }

    @objc private func updateImage() {
        imageView.image = image
        imageView.tintColor = isChecked ? .tintColor : .tertiaryLabel
    }
}
