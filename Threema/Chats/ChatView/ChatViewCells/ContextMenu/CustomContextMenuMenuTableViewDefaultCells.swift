//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import Foundation

class CustomContextMenuMenuTableViewDefaultCell: UITableViewCell, Reusable {
    let config: CustomContextMenuMenuTableViewConfig = .defaultConfig

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
        
        label.font = .preferredFont(forTextStyle: .body)
        label.numberOfLines = 0
        
        label.translatesAutoresizingMaskIntoConstraints = false
        
        return label
    }()
    
    private lazy var image: UIImageView = {
        let image = UIImageView()
        
        let configuration = UIImage.SymbolConfiguration(textStyle: .body)
        image.preferredSymbolConfiguration = configuration
        
        image.contentMode = .center
        
        image.translatesAutoresizingMaskIntoConstraints = false
        
        return image
    }()
    
    private lazy var selectedBgView: UIView = {
        let view = UIView()
        view.backgroundColor = config.tableViewHighlightedColor
        return view
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

class CustomContextMenuMenuTableViewStackCell: UITableViewCell, Reusable {
    let config: CustomContextMenuMenuTableViewConfig = .defaultConfig

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
                    textStyle: .body,
                    scale: .medium
                )
                configuration.image = action.image
                                
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
                
                if action.attributes.contains(.destructive) {
                    button.tintColor = .systemRed
                }
                else {
                    button.tintColor = .label
                }
                
                NSLayoutConstraint.activate([
                    button.topAnchor.constraint(
                        equalTo: stackView.topAnchor,
                        constant: UIFontMetrics.default.scaledValue(for: config.inlineItemTopBottomInset)
                    ),
                    button.bottomAnchor.constraint(
                        equalTo: stackView.bottomAnchor,
                        constant: -UIFontMetrics.default.scaledValue(for: config.inlineItemTopBottomInset)
                    ),
                ])
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
        stackView.setContentCompressionResistancePriority(.required, for: .vertical)
        stackView.spacing = config.inlineItemSpacing
        stackView.layoutMargins = UIEdgeInsets(
            top: 0,
            left: UIFontMetrics.default.scaledValue(for: config.inlineItemInset),
            bottom: 0,
            right: UIFontMetrics.default.scaledValue(for: config.inlineItemInset)
        )
        stackView.isLayoutMarginsRelativeArrangement = true
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
