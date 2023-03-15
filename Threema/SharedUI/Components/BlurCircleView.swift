//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

protocol BlurCircleViewConfiguration {
    var scaledSize: CGFloat { get }
    var symbolConfiguration: UIImage.SymbolConfiguration { get }
    var textStyle: UIFont.TextStyle { get }
    var textStyleFontMetrics: UIFontMetrics { get }
}

extension BlurCircleView {
    
    public enum BlurCircleViewConfigurationType {
        case `default`
        case thumbnail
        case retryAndCancel
    }
    
    private struct DefaultConfiguration: BlurCircleViewConfiguration {
        
        /// Diameter of circular view adjusted for current content size
        var scaledSize: CGFloat {
            let defaultSize: CGFloat = 52
            return textStyleFontMetrics.scaledValue(for: defaultSize)
        }
        
        /// Configuration of symbol in the center
        var symbolConfiguration: UIImage.SymbolConfiguration {
            let textStyleAndScaleConfiguration = UIImage.SymbolConfiguration(textStyle: textStyle, scale: .large)
            let weightConfiguration = UIImage.SymbolConfiguration(weight: .bold)
            return textStyleAndScaleConfiguration.applying(weightConfiguration)
        }
        
        // These should always use the same TextStyle
        let textStyle: UIFont.TextStyle = .title3
        let textStyleFontMetrics = UIFontMetrics(forTextStyle: .title3)
    }
    
    private struct ThumbnailConfiguration: BlurCircleViewConfiguration {
        
        /// Diameter of circular view adjusted for current content size
        var scaledSize: CGFloat {
            let defaultSize: CGFloat = 20
            return textStyleFontMetrics.scaledValue(for: defaultSize)
        }
        
        /// Configuration of symbol in the center
        var symbolConfiguration: UIImage.SymbolConfiguration {
            let textStyleAndScaleConfiguration = UIImage.SymbolConfiguration(textStyle: textStyle, scale: .small)
            let weightConfiguration = UIImage.SymbolConfiguration(weight: .bold)
            return textStyleAndScaleConfiguration.applying(weightConfiguration)
        }
        
        // These should always use the same TextStyle
        let textStyle: UIFont.TextStyle = .caption1
        let textStyleFontMetrics = UIFontMetrics(forTextStyle: .caption1)
    }
    
    private struct RetryAndCancelButtonConfiguration: BlurCircleViewConfiguration {
        
        /// Diameter of circular view adjusted for current content size
        var scaledSize: CGFloat {
            let defaultSize: CGFloat = 40
            return textStyleFontMetrics.scaledValue(for: defaultSize)
        }
        
        /// Configuration of symbol in the center
        var symbolConfiguration: UIImage.SymbolConfiguration {
            let textStyleAndScaleConfiguration = UIImage.SymbolConfiguration(textStyle: textStyle, scale: .medium)
            let weightConfiguration = UIImage.SymbolConfiguration(weight: .bold)
            return textStyleAndScaleConfiguration.applying(weightConfiguration)
        }
        
        // These should always use the same TextStyle
        let textStyle: UIFont.TextStyle = .body
        let textStyleFontMetrics = UIFontMetrics(forTextStyle: .body)
    }
}

/// Circle view with an vibrant symbol in the center and a blurry background
///
/// Use as-is. You should not add your own subviews.
final class BlurCircleView: UIVisualEffectView {
    
    private let viewConfiguration: BlurCircleViewConfiguration
    
    private var currentSfSymbolName: String
    
    private lazy var sizeConstraint: NSLayoutConstraint = widthAnchor
        .constraint(equalToConstant: viewConfiguration.scaledSize)
    
    // MARK: Views
    
    private lazy var symbolImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.preferredSymbolConfiguration = viewConfiguration.symbolConfiguration
        imageView.contentMode = .center
        return imageView
    }()
    
    // All the stuff to make it blurry and vibrant
    private let blurEffect = UIBlurEffect(style: .systemMaterial)
    private lazy var vibrantEffectView = UIVisualEffectView(
        effect: UIVibrancyEffect(blurEffect: blurEffect, style: .fill)
    )
    
    // MARK: - Lifecycle
    
    /// Create a new view
    ///
    /// - Parameters:
    ///   - sfSymbolName: Name of SF Symbol to show. Use just the SF Symbol name.
    ///   - configuration: BlurCircleViewConfigurationType, default value is .default
    init(
        sfSymbolName: String,
        configuration: BlurCircleViewConfigurationType = .default
    ) {
        
        switch configuration {
        case .default:
            self.viewConfiguration = DefaultConfiguration()
        case .thumbnail:
            self.viewConfiguration = ThumbnailConfiguration()
        case .retryAndCancel:
            self.viewConfiguration = RetryAndCancelButtonConfiguration()
        }
        
        self.currentSfSymbolName = sfSymbolName
        
        super.init(effect: blurEffect)
        
        configureView()
        registerObservers()
        updateSize()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Configure
    
    private func configureView() {
        // Content
        symbolImageView.image = UIImage(systemName: currentSfSymbolName)
                        
        // Layout: size
        NSLayoutConstraint.activate([
            sizeConstraint,
            heightAnchor.constraint(equalTo: widthAnchor),
        ])
                
        // Layout: Background & symbol
        vibrantEffectView.contentView.addSubview(symbolImageView)
        contentView.addSubview(vibrantEffectView)
        
        symbolImageView.translatesAutoresizingMaskIntoConstraints = false
        vibrantEffectView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            symbolImageView.centerYAnchor.constraint(equalTo: vibrantEffectView.centerYAnchor),
            symbolImageView.centerXAnchor.constraint(equalTo: vibrantEffectView.centerXAnchor),
            
            vibrantEffectView.topAnchor.constraint(equalTo: topAnchor),
            vibrantEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            vibrantEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),
            vibrantEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        
        // Show circle
        clipsToBounds = true
        
        if UIAccessibility.isReduceTransparencyEnabled || UIAccessibility.isDarkerSystemColorsEnabled {
            backgroundColor = Colors.backgroundChatBar
        }
    }
    
    private func registerObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentSizeCategoryDidChange),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
    }
    
    // MARK: - Updates
    
    func updateSymbol(to sfSymbolName: String) {
        guard currentSfSymbolName != sfSymbolName else {
            // Don't update symbol if it is still the same
            return
        }
        
        symbolImageView.image = UIImage(systemName: sfSymbolName)
        currentSfSymbolName = sfSymbolName
    }
    
    private func updateSize() {
        sizeConstraint.constant = viewConfiguration.scaledSize
        layer.cornerRadius = viewConfiguration.scaledSize / 2
    }
    
    func highlight(_ highlight: Bool, highlightingDuration: Double = 0.15, highlightingAlpha: Double = 0.8) {
        UIView.animate(withDuration: highlightingDuration) {
            self.alpha = highlight ? highlightingAlpha : 1
        }
    }
    
    // MARK: - Notifications
    
    @objc private func contentSizeCategoryDidChange() {
        updateSize()
    }
    
    // MARK: - Layout
    
    override var intrinsicContentSize: CGSize {
        CGSize(width: viewConfiguration.scaledSize, height: viewConfiguration.scaledSize)
    }
}
