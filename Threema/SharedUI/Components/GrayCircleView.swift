//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
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

// MARK: - GrayCircleView.Configuration

extension GrayCircleView {
    private enum Configuration {
        /// Helper to scale font size
        private static let textStyleFontMetrics = UIFontMetrics(forTextStyle: .caption2)
        
        /// Size of circle
        static var scaledSize: CGFloat {
            let defaultSize: CGFloat = 13
            return textStyleFontMetrics.scaledValue(for: defaultSize)
        }
        
        /// Configuration for symbol
        static var symbolConfiguration: UIImage.SymbolConfiguration {
            let defaultFontSize: CGFloat = 8
            
            let scaledFontSize = textStyleFontMetrics.scaledValue(for: defaultFontSize)
            return UIImage.SymbolConfiguration(pointSize: scaledFontSize, weight: .semibold, scale: .small)
        }
        
        /// Dynamic symbol color
        static var symbolColor: UIColor {
            Colors.grayCircleSymbol
        }
    }
}

/// Circle button with a symbol in the center and a gray background
///
/// Use as-is. You should not add your own subviews.
final class GrayCircleView: UIView {
    
    // MARK: Private properties
    
    // Workaround to prevent custom symbol initialization code
    private var currentSFSymbolName = "3maPlaceholder"
    
    private lazy var sizeConstraint = widthAnchor.constraint(equalToConstant: Configuration.scaledSize)
    
    // MARK: Views
    
    private lazy var symbolImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.preferredSymbolConfiguration = Configuration.symbolConfiguration
        imageView.contentMode = .center
        return imageView
    }()
    
    // MARK: - Lifecycle
    
    /// Create a new view with a symbol in the center
    /// - Parameter sfSymbolName: Name of SF Symbol to show
    init(
        sfSymbolName: String
    ) {
        super.init(frame: .zero)
        
        configureView()
        registerObservers()
        updateSize()
        updateSymbol(to: sfSymbolName)
        updateColors()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Configuration
    
    private func configureView() {
        // Layout: Size
        NSLayoutConstraint.activate([
            sizeConstraint,
            heightAnchor.constraint(equalTo: widthAnchor),
        ])
        
        // Layout: Symbol
        
        addSubview(symbolImageView)
        symbolImageView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            symbolImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            symbolImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
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
    
    /// Change shown symbol
    /// - Parameter sfSymbolName: Name of new symbol to show
    func updateSymbol(to sfSymbolName: String) {
        guard currentSFSymbolName != sfSymbolName else {
            // Don't update symbol if it is still the same
            return
        }
        
        symbolImageView.image = UIImage(systemName: sfSymbolName)?
            .withTintColor(Configuration.symbolColor, renderingMode: .alwaysOriginal)
        currentSFSymbolName = sfSymbolName
    }
    
    /// Update colors
    func updateColors() {
        backgroundColor = Colors.grayCircleBackground
        symbolImageView.image = symbolImageView.image?.withTintColor(Configuration.symbolColor)
    }
    
    private func updateSize() {
        sizeConstraint.constant = Configuration.scaledSize
        layer.cornerRadius = Configuration.scaledSize / 2
    }
    
    // MARK: - Notifications
    
    @objc private func contentSizeCategoryDidChange() {
        updateSize()
    }
    
    // MARK: - Layout
    
    override var intrinsicContentSize: CGSize {
        CGSize(width: Configuration.scaledSize, height: Configuration.scaledSize)
    }
}
