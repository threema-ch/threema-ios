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

final class ModalInfoController: ThemedViewController {
    
    struct UIConfiguration {
        var navigationBarTitle: String
        var topSymbol: UIImage?
        var title: String
        var description: String
        var bottomImage: UIImage?
    }
    
    struct Action {
        var title: String
        var action: () -> Void
    }
    
    private enum Configuration {
        static let layoutMargin: CGFloat = 24
        static let defaultVerticalSpacing: CGFloat = 24
        static let specialVerticalSpacing: CGFloat = 12
        static let topImageSize: CGFloat = 60
        static let buttonDistance: CGFloat = 15
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
    
    private let topImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var primaryActionButton: ThemedCodeButton = {
        let button = ThemedCodeButton { [weak self] _ in
            self?.primaryAction.action()
            self?.dismiss(animated: true)
        }
        
        button.setTitle(primaryAction.title, for: .normal)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .title3)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        
        if #available(iOS 15.0, *) {
            button.configuration = .borderedProminent()
        }
        else {
            // Fallback on earlier versions
            button.backgroundColor = Colors.primary
            button.layer.cornerCurve = .continuous
            button.layer.cornerRadius = 5.0
        }
       
        return button
    }()
    
    private lazy var secondaryActionButton: ThemedCodeButton = {
        let button = ThemedCodeButton { [weak self] _ in
            self?.secondaryAction.action()
            self?.dismiss(animated: true)
        }
        
        button.setTitle(secondaryAction.title, for: .normal)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .subheadline)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        
        button.setTitleColor(Colors.textLight, for: .normal)
       
        return button
    }()
    
    // MARK: Helper properties
    
    private let isWork = LicenseStore.requiresLicenseKey()
    
    private let uiConfiguration: UIConfiguration
    private let primaryAction: Action
    private let secondaryAction: Action
    
    // MARK: - Lifecycle
    
    @objc static func initObjC(
        navigationBarTitle: String,
        topSymbol: UIImage,
        title: String,
        description: String,
        bottomImage: UIImage? = nil,
        mainActionTitle: String,
        mainAction: @escaping () -> Void,
        secondaryActionTitle: String,
        secondaryAction: @escaping () -> Void
    ) -> ModalInfoController {
        let uiConfiguration = UIConfiguration(
            navigationBarTitle: navigationBarTitle,
            topSymbol: topSymbol,
            title: title,
            description: description,
            bottomImage: bottomImage
        )
        let mainAction = Action(title: mainActionTitle, action: mainAction)
        let secondaryAction = Action(title: secondaryActionTitle, action: secondaryAction)
        
        return ModalInfoController(
            configuration: uiConfiguration,
            mainAction: mainAction,
            secondaryAction: secondaryAction
        )
    }
    
    init(configuration: UIConfiguration, mainAction: Action, secondaryAction: Action) {
        self.uiConfiguration = configuration
        self.primaryAction = mainAction
        self.secondaryAction = secondaryAction
        
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureContent()
        configureLayout()
        
        isModalInPresentation = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        let defaults = AppGroup.userDefaults()
        defaults?.set(true, forKey: Constants.showedTestFlightFeedbackViewKey)
        defaults?.synchronize()
    }
    
    // MARK: - Configuration
    
    private func configureContent() {
        title = uiConfiguration.navigationBarTitle
        titleText.text = uiConfiguration.title
        descriptionText.text = uiConfiguration.description
        
        imageView.image = uiConfiguration.bottomImage
        topImageView.image = uiConfiguration.topSymbol
    }
    
    private func configureLayout() {
        titleText.textAlignment = .center
        descriptionText.textAlignment = .center
        
        // Build stack
        
        containerStack.addArrangedSubview(topImageView)
        containerStack.addArrangedSubview(titleText)
        
        containerStack.setCustomSpacing(Configuration.specialVerticalSpacing, after: imageView)
        containerStack.addArrangedSubview(descriptionText)
        
        primaryActionButton.translatesAutoresizingMaskIntoConstraints = false
        secondaryActionButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(primaryActionButton)
        view.addSubview(secondaryActionButton)
        
        containerStack.addArrangedSubview(imageView)
        
        // Create layout
        
        scrollView.addSubview(containerStack)
        view.addSubview(scrollView)
        
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        if let image = imageView.image {
            let aspectR = image.size.width / image.size.height
            NSLayoutConstraint.activate([
                imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 1 / aspectR),
            ])
        }
        
        if topImageView.image != nil {
            let val = UIFontMetrics(forTextStyle: .headline).scaledValue(for: Configuration.topImageSize)
            NSLayoutConstraint.activate([
                topImageView.heightAnchor.constraint(equalToConstant: val),
            ])
        }
        
        NSLayoutConstraint.activate([
            primaryActionButton.topAnchor.constraint(equalTo: scrollView.bottomAnchor),
            primaryActionButton.leadingAnchor.constraint(equalTo: descriptionText.leadingAnchor),
            primaryActionButton.trailingAnchor.constraint(equalTo: descriptionText.trailingAnchor),
            primaryActionButton.bottomAnchor.constraint(
                equalTo: secondaryActionButton.topAnchor,
                constant: -Configuration.buttonDistance
            ),
            
            secondaryActionButton.leadingAnchor.constraint(equalTo: primaryActionButton.leadingAnchor),
            secondaryActionButton.trailingAnchor.constraint(equalTo: primaryActionButton.trailingAnchor),
            secondaryActionButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
        
        NSLayoutConstraint.activate([
            containerStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            containerStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            containerStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            containerStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            
            scrollView.frameLayoutGuide.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.frameLayoutGuide.leadingAnchor.constraint(equalTo: view.leadingAnchor),
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
