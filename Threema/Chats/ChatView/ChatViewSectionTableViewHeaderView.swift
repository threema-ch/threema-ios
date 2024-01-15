//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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

/// Default section headers for chat view
///
/// It has a blurry background and a vibrancy effect on the title
class ChatViewSectionTableViewHeaderView: UITableViewHeaderFooterView {
    
    /// Title shown in section header
    var title: String? {
        didSet {
            titleLabel.text = title
        }
    }
    
    // MARK: - Views
    
    private lazy var titleLabel = {
        let label = UILabel()
        
        label.numberOfLines = 4
        label.textAlignment = .center
        
        label.font = ChatViewConfiguration.SectionHeader.DateLabel.font
        label.adjustsFontForContentSizeCategory = true
        
        return label
    }()
    
    // All the stuff to make it blurry and vibrant
    private let blurEffect = UIBlurEffect(style: ChatViewConfiguration.SectionHeader.blurEffectStyle)
    private lazy var vibrancyEffectView = UIVisualEffectView(
        effect: UIVibrancyEffect(blurEffect: blurEffect, style: .fill)
    )
    private lazy var backgroundVisualEffectView = {
        let visualEffectView = UIVisualEffectView(effect: self.blurEffect)
        
        visualEffectView.layer.cornerCurve = .continuous
        // Needed for rounded corners
        visualEffectView.clipsToBounds = true

        visualEffectView.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: ChatViewConfiguration.SectionHeader.DateLabel.defaultTopBottomInset,
            leading: ChatViewConfiguration.SectionHeader.DateLabel.defaultLeadingTrailingInset,
            bottom: ChatViewConfiguration.SectionHeader.DateLabel.defaultTopBottomInset,
            trailing: ChatViewConfiguration.SectionHeader.DateLabel.defaultLeadingTrailingInset
        )

        return visualEffectView
    }()
    
    // MARK: - Lifecycle
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        configureView()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configureView() {
        backgroundConfiguration = .clear()
        
        directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: ChatViewConfiguration.SectionHeader.defaultTopAndBottomInset,
            leading: directionalLayoutMargins.leading,
            bottom: ChatViewConfiguration.SectionHeader.defaultTopAndBottomInset,
            trailing: directionalLayoutMargins.trailing
        )
        
        vibrancyEffectView.contentView.addSubview(titleLabel)
        backgroundVisualEffectView.contentView.addSubview(vibrancyEffectView)
        contentView.addSubview(backgroundVisualEffectView)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        vibrancyEffectView.translatesAutoresizingMaskIntoConstraints = false
        backgroundVisualEffectView.translatesAutoresizingMaskIntoConstraints = false
        
        let backgroundBottomConstraint = backgroundVisualEffectView.bottomAnchor.constraint(
            equalTo: contentView.layoutMarginsGuide.bottomAnchor
        )
        // This needs to be non-required otherwise we sometimes have breaking constraints while scrolling, because
        // the height set by the table view doesn't match the height calculated with Auto Layout. Because the difference
        // is so small it is not recognizable by the user.
        backgroundBottomConstraint.priority = .defaultHigh
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: backgroundVisualEffectView.layoutMarginsGuide.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: backgroundVisualEffectView.layoutMarginsGuide.leadingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: backgroundVisualEffectView.layoutMarginsGuide.bottomAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: backgroundVisualEffectView.layoutMarginsGuide.trailingAnchor),
            
            vibrancyEffectView.topAnchor.constraint(equalTo: backgroundVisualEffectView.contentView.topAnchor),
            vibrancyEffectView.leadingAnchor.constraint(equalTo: backgroundVisualEffectView.contentView.leadingAnchor),
            vibrancyEffectView.bottomAnchor.constraint(equalTo: backgroundVisualEffectView.contentView.bottomAnchor),
            vibrancyEffectView.trailingAnchor.constraint(
                equalTo: backgroundVisualEffectView.contentView.trailingAnchor
            ),
            
            backgroundVisualEffectView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            backgroundBottomConstraint,
            
            backgroundVisualEffectView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            backgroundVisualEffectView.widthAnchor.constraint(
                lessThanOrEqualTo: contentView.readableContentGuide.widthAnchor
            ),
        ])
        
        if UIAccessibility.isReduceTransparencyEnabled || UIAccessibility.isDarkerSystemColorsEnabled {
            backgroundVisualEffectView.backgroundColor = Colors.backgroundChatBar
        }
    }
    
    // MARK: - Overrides
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Ensure that we always have a correct corner radius
        
        // The frame of the background is sometimes 0 here (often on the initial load of the chat view), but this
        // calculates the correct height that the background will eventually have.
        let backgroundHeight = titleLabel.intrinsicContentSize.height +
            2 * ChatViewConfiguration.SectionHeader.DateLabel.defaultTopBottomInset
    
        let newCornerRadius = min(
            ChatViewConfiguration.SectionHeader.cornerRadius,
            backgroundHeight / 2.0
        )
        
        backgroundVisualEffectView.layer.cornerRadius = newCornerRadius
    }
}

// MARK: - Reusable

extension ChatViewSectionTableViewHeaderView: Reusable { }
