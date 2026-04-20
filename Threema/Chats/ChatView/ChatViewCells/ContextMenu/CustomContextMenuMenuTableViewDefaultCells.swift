import Foundation

final class CustomContextMenuMenuTableViewDefaultCell: UITableViewCell, Reusable {
    private let config: CustomContextMenuMenuTableViewConfig =
        if #available(iOS 26.0, *) {
            .glassConfig
        }
        else {
            .defaultConfig
        }

    var action: ChatViewMessageActionsProvider.MessageAction? {
        didSet {
            guard let action else {
                label.text = nil
                image.image = nil
                return
            }
            
            label.text = action.title
            image.image = action.image
            
            if action.attributes.contains(.destructive) {
                label.textColor = .systemRed
                image.tintColor = .systemRed
            }
            else {
                label.textColor = .label
                image.tintColor = .label
            }
        }
    }
    
    // MARK: - Subviews
    
    private lazy var label: UILabel = {
        let label = UILabel()
        
        label.font = .preferredFont(forTextStyle: config.preferredTextStyle)
        label.numberOfLines = 0
        
        label.translatesAutoresizingMaskIntoConstraints = false
        
        return label
    }()
    
    private lazy var image: UIImageView = {
        let image = UIImageView()
        
        let configuration = UIImage.SymbolConfiguration(textStyle: config.preferredTextStyle)
        image.preferredSymbolConfiguration = configuration
        
        image.contentMode = .center
        
        image.translatesAutoresizingMaskIntoConstraints = false
        
        return image
    }()
    
    private lazy var selectedBgView: UIView = {
        let view = UIView()
        if #available(iOS 26.0, *) {
            let selectedView = UIView()
            view.addSubview(selectedView)
            selectedView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                selectedView.topAnchor.constraint(equalTo: view.topAnchor),
                selectedView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: config.tableViewInset),
                selectedView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                selectedView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -config.tableViewInset),
            ])
            selectedView.backgroundColor = config.tableViewHighlightedColor
            selectedView.cornerConfiguration = .uniformCorners(
                radius: UICornerRadius(floatLiteral: config.defaultSelectionBackgroundCornerRadius)
            )
        }
        else {
            view.backgroundColor = config.tableViewHighlightedColor
        }

        return view
    }()
    
    // MARK: - Lifecycle
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
       
        if #available(iOS 26.0, *) {
            configureCellPostGlass()
        }
        else {
            configureCellPreGlass()
        }
    }
    
    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Private functions

    private func configureCellPostGlass() {
        backgroundColor = .clear
        contentView.addSubview(label)
        selectedBackgroundView = selectedBgView
        
        // We do not show the image for a11y fonts
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(
                    equalTo: contentView.leadingAnchor,
                    constant: config.itemLeadingTrailingInset
                ),
            ])
        }
        else {
            contentView.addSubview(image)

            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(
                    equalTo: image.trailingAnchor,
                    constant: config.defaultItemSpacing
                ),
                image.firstBaselineAnchor.constraint(equalTo: label.firstBaselineAnchor),
                image.centerXAnchor.constraint(
                    equalTo: contentView.leadingAnchor,
                    constant: UIFontMetrics.default.scaledValue(
                        for: config.itemLeadingTrailingInset
                    ) + config.defaultImageCenterInset
                ),
            ])
        }
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: UIFontMetrics.default.scaledValue(
                    for: config.defaultItemTopBottomInset
                )
            ),
            label.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -config.itemLeadingTrailingInset
            ),
            label.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -UIFontMetrics.default.scaledValue(
                    for: config.defaultItemTopBottomInset
                )
            ),
        ])
    }
    
    private func configureCellPreGlass() {
        backgroundColor = .clear
        contentView.addSubview(label)
        selectedBackgroundView = selectedBgView
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: config.itemLeadingTrailingInset
            ),
            label.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: UIFontMetrics.default.scaledValue(
                    for: config.defaultItemTopBottomInset
                ) + config.defaultItemTopTweak
            ),
            label.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -UIFontMetrics.default.scaledValue(for: config.defaultItemTopBottomInset)
            ),
            
        ])
        
        // We do not show the image for a11y fonts
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            NSLayoutConstraint.activate([
                label.trailingAnchor.constraint(
                    lessThanOrEqualTo: contentView.trailingAnchor,
                    constant: -config.itemLeadingTrailingInset
                ),
            ])
        }
        else {
            contentView.addSubview(image)

            NSLayoutConstraint.activate([
                label.trailingAnchor.constraint(
                    lessThanOrEqualTo: image.leadingAnchor,
                    constant: config.defaultItemSpacing
                ),
                image.centerYAnchor.constraint(equalTo: label.centerYAnchor),
                image.centerXAnchor.constraint(
                    equalTo: contentView.trailingAnchor,
                    constant: -(UIFontMetrics.default.scaledValue(
                        for: config.itemLeadingTrailingInset
                    ) + config.defaultImageCenterInset)
                ),
            ])
        }
    }
}

final class CustomContextMenuMenuTableViewStackCell: UITableViewCell, Reusable {
    let config: CustomContextMenuMenuTableViewConfig =
        if #available(iOS 26.0, *) {
            .glassConfig
        }
        else {
            .defaultConfig
        }

    weak var menuDelegate: CustomContextMenuMenuTableViewDelegate?

    var actions: [ChatViewMessageActionsProvider.MessageAction]? {
        didSet {
            guard let actions else {
                return
            }
           
            for arrangedSubview in stackView.arrangedSubviews {
                arrangedSubview.removeFromSuperview()
            }
            
            for action in actions {
                
                var configuration = UIButton.Configuration.plain()
                
                configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
                    textStyle: config.preferredTextStyle,
                    scale: .medium
                )
                configuration.image = action.image
                
                if action.attributes.contains(.destructive) {
                    configuration.baseForegroundColor = .systemRed
                }
                else {
                    configuration.baseForegroundColor = .label
                }
                
                let button = UIButton(type: .custom)
                button.configuration = configuration
                button.layer.cornerRadius = config.inlineItemCornerRadius
                button.configurationUpdateHandler = { [weak self] button in
                    guard let self else {
                        return
                    }
                    
                    if button.state == .highlighted {
                        button.backgroundColor = config.tableViewHighlightedColor
                    }
                    else {
                        button.backgroundColor = .clear
                    }
                }
                
                button.addAction(
                    UIAction { [weak self] _ in
                        self?.menuDelegate?.didSelectAction { action.handler() }
                    },
                    for: .touchUpInside
                )
                
                stackView.addArrangedSubview(button)
            }
        }
    }
    
    // MARK: - Subviews
    
    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.setContentHuggingPriority(.required, for: .vertical)
        stackView.spacing = config.inlineItemSpacing
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: UIFontMetrics.default.scaledValue(for: config.inlineItemTopBottomInset),
            leading: UIFontMetrics.default.scaledValue(for: config.inlineItemInset),
            bottom: UIFontMetrics.default.scaledValue(for: config.inlineItemTopBottomInset),
            trailing: UIFontMetrics.default.scaledValue(for: config.inlineItemInset)
        )
        return stackView
    }()
    
    // MARK: - Lifecycle
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureCell()
    }
    
    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Private functions

    private func configureCell() {
        backgroundColor = .clear
        selectionStyle = .none
        contentView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }
}
