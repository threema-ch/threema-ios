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

/// Show symbol and/or text meant as metadata (like the file size of an image or runtime of a video)
final class MessageSymbolMetadataView: UIView {
    
    /// Symbol to show before the text (leading side) if any
    var symbolName: String? {
        didSet {
            guard symbolName != oldValue else {
                return
            }
            
            if let symbolName {
                var image = UIImage(systemName: symbolName)
                
                if image == nil {
                    image = UIImage(named: symbolName)
                }
                
                symbolImageView.image = image
                showSymbol()
            }
            else {
                hideSymbol()
                symbolImageView.image = nil
            }
        }
    }
    
    /// Metadata string to show if any
    var metadataString: String? {
        didSet {
            guard metadataString != oldValue else {
                return
            }
            
            if let metadataString {
                metadataLabel.text = metadataString
                showMetadataLabel()
            }
            else {
                hideMetaDataLabel()
                metadataLabel.text = nil
            }
        }
    }
    
    /// Allows overriding the default text and symbol color to something custom
    var overrideColor: UIColor? {
        didSet {
            updateColors()
        }
    }
    
    // MARK: - Private properties
    
    private lazy var constantScaler = UIFontMetrics(forTextStyle: ChatViewConfiguration.MessageMetadata.textStyle)
    
    private lazy var symbolXCenterLeadingDistance: CGFloat = constantScaler.scaledValue(
        // Adapt for content size categories
        for: ChatViewConfiguration.MessageMetadata.defaultSymbolCenterInset
    )
    
    private lazy var metadataLabelLeadingInset: CGFloat = {
        // The metadata label is as far away from the symbol center as its center is form the trailing end plus the
        // space
        let offset = 2 * symbolXCenterLeadingDistance // This is already scaled
        let scaledSpace = constantScaler.scaledValue(
            for: ChatViewConfiguration.MessageMetadata.defaultLabelAndSymbolSpace
        )
        
        return offset + scaledSpace
    }()
    
    // MARK: - Views & constraints
    
    private lazy var symbolImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.preferredSymbolConfiguration = ChatViewConfiguration.MessageMetadata.symbolConfiguration
        return imageView
    }()
    
    private lazy var symbolOnlyConstraints = [
        symbolImageView.topAnchor.constraint(equalTo: topAnchor),
        symbolImageView.bottomAnchor.constraint(equalTo: bottomAnchor),
        symbolImageView.centerXAnchor.constraint(equalTo: trailingAnchor, constant: -symbolXCenterLeadingDistance),
    ]
    
    private lazy var metadataLabel = MessageMetadataTextLabel()
    
    private lazy var metadataLabelLeadingInsetConstraint = metadataLabel.leadingAnchor.constraint(
        equalTo: leadingAnchor,
        constant: metadataLabelLeadingInset
    )
    
    private lazy var metadataLabelConstraints = [
        metadataLabel.topAnchor.constraint(equalTo: topAnchor),
        metadataLabelLeadingInsetConstraint,
        metadataLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
        metadataLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
    ]
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLayout()
        updateColors()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayout()
        updateColors()
    }
    
    convenience init() {
        self.init(frame: .zero)
    }
    
    private func configureLayout() {
        addSubview(symbolImageView)
        addSubview(metadataLabel)
        
        symbolImageView.translatesAutoresizingMaskIntoConstraints = false
        metadataLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            symbolImageView.firstBaselineAnchor.constraint(equalTo: metadataLabel.firstBaselineAnchor),
            symbolImageView.centerXAnchor.constraint(equalTo: leadingAnchor, constant: symbolXCenterLeadingDistance),
        ])
        
        // In the initial state both public properties are `nil` so the views are hidden
        hideSymbol()
        hideMetaDataLabel()
    }
    
    // MARK: - Update
    
    func updateColors() {
        if let overrideColor {
            symbolImageView.image = symbolImageView.image?.withTintColor(overrideColor, renderingMode: .alwaysOriginal)
            Colors.setTextColor(overrideColor, label: metadataLabel)
        }
        else {
            symbolImageView.image = symbolImageView.image?.withTintColor(
                Colors.textLight,
                renderingMode: .alwaysOriginal
            )
            Colors.setTextColor(Colors.textLight, label: metadataLabel)
        }
    }
    
    // MARK: - Show & hide
    
    private func showSymbol() {
        guard symbolImageView.isHidden else {
            return
        }
        
        symbolImageView.isHidden = false
        metadataLabelLeadingInsetConstraint.constant = metadataLabelLeadingInset
    }
    
    private func hideSymbol() {
        guard !symbolImageView.isHidden else {
            return
        }
        
        symbolImageView.isHidden = true
        metadataLabelLeadingInsetConstraint.constant = 0
    }
    
    private func showMetadataLabel() {
        guard metadataLabel.isHidden else {
            return
        }
        
        metadataLabel.isHidden = false
        NSLayoutConstraint.deactivate(symbolOnlyConstraints)
        NSLayoutConstraint.activate(metadataLabelConstraints)
    }
    
    private func hideMetaDataLabel() {
        guard !metadataLabel.isHidden else {
            return
        }
        
        metadataLabel.isHidden = true
        NSLayoutConstraint.deactivate(metadataLabelConstraints)
        NSLayoutConstraint.activate(symbolOnlyConstraints)
    }
}
