//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2024 Threema GmbH
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

import UIKit

class QuickActionButton: UIButton {
    
    private let cornerRadius: CGFloat = 10
    private let shadowRadius: CGFloat = 8
    
    private let buttonImageNameProvider: QuickAction.ImageNameProvider
    
    private let action: (QuickActionUpdate) -> Void
    
    private lazy var highlightAnimator = UIViewPropertyAnimator.barButtonHighlightAnimator(for: self)
    
    init(
        imageNameProvider: @escaping QuickAction.ImageNameProvider,
        title: String,
        accessibilityIdentifier identifier: String,
        action: @escaping (QuickActionUpdate) -> Void,
        shadow: Bool = true
    ) {
        self.buttonImageNameProvider = imageNameProvider
        self.action = action
        
        super.init(frame: .zero)
        
        configureButton(with: title, shadow: shadow)
        accessibilityIdentifier = identifier
        updateColors()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateColors),
            name: Notification.Name(rawValue: kNotificationColorThemeChanged),
            object: nil
        )
    }
    
    @available(*, unavailable, message: "Use `init(imageName:title:)` instead")
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        highlightAnimator.stopAnimation(true)
    }
    
    // MARK: Subviews
    
    private let buttonImageView: UIImageView = {
        let imageView = UIImageView()
        
        imageView.contentMode = .scaleAspectFit
        
        imageView.heightAnchor.constraint(equalToConstant: 28).isActive = true
        
        return imageView
    }()
    
    private let buttonTitleLabel: UILabel = {
        let label = UILabel()
        
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true
        
        return label
    }()
    
    private let contentStack: UIStackView = {
        let stack = UIStackView()
        
        stack.axis = .vertical
        stack.alignment = .center
        stack.distribution = .equalSpacing
        stack.spacing = 2
        
        // Needed to get UIEvents
        stack.isUserInteractionEnabled = false
        
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 8,
            leading: 8,
            bottom: 8,
            trailing: 8
        )
        
        return stack
    }()
    
    private func configureButton(with title: String, shadow: Bool) {
        updateButtonImage()
        
        buttonTitleLabel.text = title
        accessibilityLabel = title
    
        // Configure corner radius and drop shadow
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous
        
        if shadow {
            layer.shadowColor = UIColor(red: 117 / 255, green: 117 / 255, blue: 117 / 255, alpha: 0.1).cgColor
            layer.shadowOffset = CGSize(width: 0, height: 1)
            layer.shadowRadius = shadowRadius
            layer.shadowOpacity = 1
        }
        
        contentStack.addArrangedSubview(buttonImageView)
        contentStack.addArrangedSubview(buttonTitleLabel)
  
        addSubview(contentStack)
        
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        
        // Interactivity
        addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Optimize shadow rendering <https://developer.apple.com/videos/play/tech-talks/10857/?time=1091>
        // We cannot do it during initialization as the size changes over time
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
    }
    
    private func updateButtonImage() {
        var image = BundleUtil.imageNamed("\(buttonImageNameProvider())_semibold.L")
        
        // TODO: (IOS-1945) Replace all semibold.L PDF symbols and use custom or SFSymbols
        // If not found, we try to fallback to our custom SFSymbols and apply the configurations to get the right icon
        if image == nil {
            image = BundleUtil.imageNamed(buttonImageNameProvider())
            var weightConfig = UIImage.SymbolConfiguration(weight: .semibold)
            var scaleConfig = UIImage.SymbolConfiguration(scale: .large)
            let combinedConfig = scaleConfig.applying(weightConfig)
            image = image?.withConfiguration(combinedConfig)
        }
        
        assert(image != nil, "SF Symbol: semibold & L required")
        
        buttonImageView.image = image
        buttonImageView.sizeToFit()
    }
    
    @objc private func updateColors() {
        tintColor = .primary
        buttonTitleLabel.textColor = .primary
        backgroundColor = Colors.backgroundQuickActionButton
    }
    
    override var isHighlighted: Bool {
        didSet {
            guard isHighlighted != oldValue else {
                return
            }
                    
            // Do not pause animation for UI tests, it will break the test
            if !ProcessInfoHelper.isRunningForScreenshots {
                highlightAnimator.pauseAnimation()
                
                if isHighlighted {
                    highlightAnimator.isReversed = false
                    highlightAnimator.startAnimation()
                }
                else {
                    highlightAnimator.isReversed = true
                    highlightAnimator.startAnimation()
                }
            }
        }
    }
    
    override var isSelected: Bool {
        didSet {
            guard isSelected != oldValue else {
                return
            }
            backgroundColor = Colors.backgroundQuickActionButton
            if isSelected {
                // Do not pause animation for UI tests, it will break the test
                if ProcessInfoHelper.isRunningForScreenshots {
                    isSelected = false
                }
                else {
                    // Reset highlight animation
                    highlightAnimator.pauseAnimation()
                    // TODO: Because this still animates the change there's a weird fade in of the
                    //       selected background change.
                    highlightAnimator.fractionComplete = 0
                    
                    // Automatically reset after 0.1 s
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.isSelected = false
                    }
                }
            }
        }
    }
    
    // MARK: - Interaction

    @objc private func buttonTapped() {
        isSelected = true
        action(self)
    }
}

// MARK: - QuickActionUpdate

extension QuickActionButton: QuickActionUpdate {
    func reload() {
        updateButtonImage()
    }
    
    func hide() {
        isHidden = true
    }
}
