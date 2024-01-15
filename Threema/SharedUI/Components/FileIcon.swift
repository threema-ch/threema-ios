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

// MARK: - FileIcon.Configuration

extension FileIcon {
    enum Configuration {
        /// Offset of label or symbol from center of icon
        static let labelOrSymbolVerticalCenterOffset = 2.25
        
        /// Leading and trailing inset of label text
        static let leadingAndTrailingMargin: CGFloat = 4.25
        /// For correct centering we add some extra spacing to the leading margin
        static let additionalLeadingMargin: CGFloat = 0.75
        
        /// File extension label font
        static let font = UIFont.systemFont(ofSize: 9.5, weight: .bold)
        
        static let symbolConfiguration = UIImage.SymbolConfiguration(
            font: UIFont.systemFont(ofSize: 11),
            scale: .large
        )
    }
}

/// Fixed size file icon with a possible symbol or string (i.e. extension) on top of it
///
/// Same appearance for light and dark mode
final class FileIcon: UIImageView {
    
    /// File symbol to show
    enum FileSymbol {
        /// Nothing
        case noSymbol
        /// The extension string is shown as text overlay or symbol (for a hand curated list of strings)
        case `extension`(String)
        /// Overlay an SF Symbol with the passed name
        case customSFSymbol(named: String)
    }
    
    // MARK: - Views
    
    // Only one of these two views should be shown at the same time
    
    private lazy var fileSymbolLabel: UILabel = {
        let label = UILabel()
        
        label.textColor = Colors.black
        
        // We don't adapt to content sizes as this would break the appearance completely
        if let roundedFontDescriptor = Configuration.font.fontDescriptor.withDesign(
            UIFontDescriptor.SystemDesign.rounded
        ) {
            // A size of 0 does't override the existing size
            label.font = UIFont(descriptor: roundedFontDescriptor, size: 0)
        }
        else {
            label.font = Configuration.font
        }
        
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        
        // Prevent stretching with longer extensions
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        return label
    }()
    
    private lazy var fileSymbolView: UIImageView = {
        let imageView = UIImageView()
        
        imageView.preferredSymbolConfiguration = Configuration.symbolConfiguration
        imageView.tintColor = .black
        
        return imageView
    }()
    
    // MARK: - Lifecycle
    
    /// Create a new file icon with the passed file symbol
    ///
    /// You can update the file symbol later by calling `setFileSymbol(to:)`.
    ///
    /// - Parameter fileSymbol: File symbol to show
    init(with fileSymbol: FileSymbol = .noSymbol) {
        super.init(image: BundleUtil.imageNamed("DocumentSmall"))
                
        configureView()
        setFileSymbol(to: fileSymbol)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Configuration
    
    private func configureView() {
        // Prevent stretching
        setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        addSubview(fileSymbolLabel)
        addSubview(fileSymbolView)
        fileSymbolLabel.translatesAutoresizingMaskIntoConstraints = false
        fileSymbolView.translatesAutoresizingMaskIntoConstraints = false
                
        NSLayoutConstraint.activate([
            
            // Label
            
            fileSymbolLabel.centerYAnchor.constraint(
                equalTo: centerYAnchor,
                constant: Configuration.labelOrSymbolVerticalCenterOffset
            ),
            
            fileSymbolLabel.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: Configuration.additionalLeadingMargin + Configuration.leadingAndTrailingMargin
            ),
            fileSymbolLabel.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -Configuration.leadingAndTrailingMargin
            ),
            
            // Symbol
            
            fileSymbolView.centerYAnchor.constraint(
                equalTo: centerYAnchor,
                constant: Configuration.labelOrSymbolVerticalCenterOffset
            ),
            
            // The symbol configuration should fit inside the icon
            fileSymbolView.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }
    
    // MARK: - Updates
    
    func updateColors() {
        fileSymbolLabel.textColor = Colors.black
    }
    
    // MARK: - Set file type
    
    /// Switch file symbol to new value
    /// - Parameter fileSymbol: File symbol to show
    func setFileSymbol(to fileSymbol: FileSymbol) {
        switch fileSymbol {
        case .noSymbol:
            fileSymbolLabel.isHidden = true
            fileSymbolView.isHidden = true
            
        case let .extension(extensionString):
            if let sfSymbolName = extensionsSFSymbolName(for: extensionString) {
                showSFSymbol(with: sfSymbolName)
            }
            else {
                fileSymbolView.isHidden = true
                fileSymbolLabel.text = extensionString.uppercased()
                fileSymbolLabel.isHidden = false
            }
            
        case let .customSFSymbol(sfSymbolName):
            showSFSymbol(with: sfSymbolName)
        }
    }
    
    // MARK: Helper
    
    // For some special extensions we also use symbols instead of extensions
    private func extensionsSFSymbolName(for extensionString: String) -> String? {
        switch extensionString.lowercased() {
        case "vcf": // A contact file
            return "person.crop.circle"
        default:
            return nil
        }
    }
    
    private func showSFSymbol(with sfSymbolName: String) {
        fileSymbolLabel.isHidden = true
        fileSymbolView.image = UIImage(systemName: sfSymbolName)
        fileSymbolView.isHidden = false
    }
}
