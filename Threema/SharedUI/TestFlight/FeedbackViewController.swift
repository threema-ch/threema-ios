//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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

/// Show all verification levels with description.
///
/// Use as-is.
final class FeedbackViewController: ThemedViewController {
        
    private enum Configuration {
        static let layoutMargin: CGFloat = 24
        static let defaultVerticalSpacing: CGFloat = 24
        static let specialVerticalSpacing: CGFloat = 12
    }
            
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
    
    private let titleText: UILabel = {
        let label = UILabel()
        
        label.font = UIFont.preferredFont(forTextStyle: .title1)
        label.adjustsFontForContentSizeCategory = true
        
        label.numberOfLines = 0
        
        return label
    }()

    private let descriptionText: UILabel = {
        let label = UILabel()
        
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        
        label.numberOfLines = 0
                
        return label
    }()
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
          
    // MARK: Helper properties
    
    private let isWork = LicenseStore.requiresLicenseKey()

    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        configureContent()
        configureLayout()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        let defaults = AppGroup.userDefaults()
        defaults?.set(true, forKey: Constants.showedTestFlightFeedbackViewKey)
        defaults?.synchronize()
    }
        
    // MARK: - Configuration
     
    private func configureContent() {
        title = BundleUtil.localizedString(forKey: "testflight_feedback_viewtitle")
        titleText.text = BundleUtil.localizedString(forKey: "testflight_feedback_title")
        descriptionText.text = BundleUtil.localizedString(forKey: "testflight_feedback_description")
        
        let theme = Colors.theme == .dark ? "dark" : "light"
        imageView.image = BundleUtil.imageNamed("Feedback_\(theme)")
    }
    
    private func configureLayout() {
        let aspectR = imageView.image!.size.width / imageView.image!.size.height
        
        // Build stack
        containerStack.addArrangedSubview(titleText)
        
        containerStack.setCustomSpacing(Configuration.specialVerticalSpacing, after: imageView)
        containerStack.addArrangedSubview(descriptionText)
        containerStack.addArrangedSubview(imageView)
        
        // Create layout
        
        scrollView.addSubview(containerStack)
        view.addSubview(scrollView)
        
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 1 / aspectR),
            
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
    
    // Overrides
    
    override func updateColors() {
        super.updateColors()
        
        configureContent()
    }
}
