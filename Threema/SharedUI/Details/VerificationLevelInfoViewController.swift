//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2024 Threema GmbH
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

import SwiftUI
import UIKit

/// Show all verification levels with description.
///
/// Use as-is.
final class VerificationLevelInfoViewController: ThemedViewController {
    
    private enum Configuration {
        static let layoutMargin: CGFloat = 24
        static let defaultVerticalSpacing: CGFloat = 24
        static let extraVerticalSpacing: CGFloat = 32
    }
    
    // MARK: Subviews
        
    // Layout
    
    private let scrollView = UIScrollView()
    
    private let containerStack: UIStackView = {
        let stackView = UIStackView()
      
        stackView.axis = .vertical
        stackView.spacing = Configuration.defaultVerticalSpacing
        
        stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: Configuration.layoutMargin,
            leading: Configuration.layoutMargin,
            bottom: Configuration.layoutMargin,
            trailing: Configuration.layoutMargin
        )
        stackView.isLayoutMarginsRelativeArrangement = true
        
        return stackView
    }()
    
    // Content
    
    private let descriptionText: UILabel = {
        let label = UILabel()
        
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        
        label.numberOfLines = 0
                
        return label
    }()
    
    // These title are only shown if `isWork`
    private lazy var workTitle = configuredHeadlineLabel()
    private lazy var otherTitle = configuredHeadlineLabel()
    
    private lazy var level0View = LevelView(for: 0)
    private lazy var level1View = LevelView(for: 1)
    private lazy var level2View = LevelView(for: 2)
    private lazy var level3View = LevelView(for: 3)
    private lazy var level4View = LevelView(for: 4)
    
    // MARK: Helper properties
    
    private let isWork = LicenseStore.requiresLicenseKey()

    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        configureContent()
        configureLayout()
    }
    
    // MARK: - Configuration
     
    private func configureContent() {
        title = BundleUtil.localizedString(forKey: "verification_level_title")
        
        descriptionText.text = BundleUtil.localizedString(forKey: "verification_level_text")
        
        workTitle.text = BundleUtil.localizedString(forKey: "verification_level_section_work")
        otherTitle.text = BundleUtil.localizedString(forKey: "verification_level_section_other")
    }
    
    private func configureLayout() {
        
        // Build stack
        
        containerStack.addArrangedSubview(descriptionText)
        
        if isWork {
            containerStack.setCustomSpacing(Configuration.extraVerticalSpacing, after: descriptionText)
            containerStack.addArrangedSubview(workTitle)
            
            containerStack.addArrangedSubview(level4View)
            containerStack.addArrangedSubview(level3View)
            
            containerStack.setCustomSpacing(Configuration.extraVerticalSpacing, after: level3View)
            containerStack.addArrangedSubview(otherTitle)
        }
        
        containerStack.addArrangedSubview(level2View)
        containerStack.addArrangedSubview(level1View)
        containerStack.addArrangedSubview(level0View)

        // Create layout
        
        scrollView.addSubview(containerStack)
        view.addSubview(scrollView)
        
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            containerStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            containerStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            containerStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            containerStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            
            scrollView.frameLayoutGuide.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.frameLayoutGuide.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.frameLayoutGuide.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.frameLayoutGuide.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // Limit width to screen width (= no horizontal scrolling)
            containerStack.widthAnchor.constraint(equalTo: view.widthAnchor),
        ])
    }
    
    // MARK: - View creation helper
    
    private func configuredHeadlineLabel() -> UILabel {
        let label = UILabel()
        
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true
        
        label.numberOfLines = 0
        
        return label
    }
}
