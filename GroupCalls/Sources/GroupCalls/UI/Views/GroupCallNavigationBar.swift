//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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
import UIKit

class GroupCallNavigationBar: UIView {
    
    // MARK: - Subviews

    private lazy var dismissButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "chevron.down")
        configuration.preferredSymbolConfigurationForImage = GroupCallUIConfiguration.NavigationBar
            .dismissButtonSymbolConfiguration
        
        let action = UIAction { [weak self] _ in
            Task { @MainActor in
                await self?.groupCallViewControllerDelegate?.dismiss()
            }
        }
        
        let button = UIButton(configuration: configuration, primaryAction: action)
        button.tintColor = .white
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityLabel = dependencies.groupCallBundleUtil
            .localizedString(for: "group_call_accessibility_hide_view")
        
        return button
    }()
    
    private var headerLabel: UILabel = {
        let headerLabel = UILabel()
        
        headerLabel.text = "-"
        headerLabel.textColor = .white
        headerLabel.font = UIFont.systemFont(
            ofSize: UIFont.preferredFont(
                forTextStyle: GroupCallUIConfiguration.NavigationBar.headerTextStyle
            ).pointSize,
            weight: GroupCallUIConfiguration.NavigationBar.headerFontWeight
        )
        
        // Needed for longer texts to be truncated before the participants number on the trailing side
        headerLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        
        return headerLabel
    }()
    
    private var timeLabel: UILabel = {
        let timeLabel = UILabel()
        
        timeLabel.text = "0:00"
        timeLabel.textColor = .white
        
        timeLabel.font = UIFont.monospacedDigitSystemFont(
            ofSize: UIFont.preferredFont(
                forTextStyle: GroupCallUIConfiguration.NavigationBar.smallerTextStyle
            ).pointSize,
            weight: .regular
        )
        
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        return timeLabel
    }()
    
    private var participantIcon: UIImageView = {
        let image = UIImage(systemName: "person.2.fill")
        
        let imageView = UIImageView(image: image)
        imageView.preferredSymbolConfiguration = GroupCallUIConfiguration.NavigationBar.smallerSymbolConfiguration
        imageView.tintColor = .white
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        return imageView
    }()
    
    private var participantCountLabel: UILabel = {
        let participantCountLabel = UILabel()
        
        participantCountLabel.text = "0"
        participantCountLabel.textColor = .white
        
        participantCountLabel.font = UIFont.monospacedDigitSystemFont(
            ofSize: UIFont.preferredFont(
                forTextStyle: GroupCallUIConfiguration.NavigationBar.smallerTextStyle
            ).pointSize,
            weight: .regular
        )
        
        participantCountLabel.translatesAutoresizingMaskIntoConstraints = false
        
        return participantCountLabel
    }()
    
    private lazy var gradientLayer: CAGradientLayer = {
        let gradientLayer = CAGradientLayer()
        
        gradientLayer.colors = [
            UIColor.black.withAlphaComponent(GroupCallUIConfiguration.General.initialGradientOpacity).cgColor,
            UIColor.black.withAlphaComponent(0).cgColor,
        ]
        
        gradientLayer.frame = bounds
        
        return gradientLayer
    }()
    
    // MARK: - Internal Properties
    
    private var isNavBarHidden = false
    private weak var groupCallViewControllerDelegate: GroupCallViewControllerDelegate?
    private var dependencies: Dependencies

    // MARK: - Lifecycle

    init(groupCallViewControllerDelegate: GroupCallViewControllerDelegate, dependencies: Dependencies) {
        self.groupCallViewControllerDelegate = groupCallViewControllerDelegate
        self.dependencies = dependencies
        super.init(frame: .zero)
        
        configureView()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        gradientLayer.frame = bounds
    }
    
    // MARK: - Public Functions
    
    // TODO: (IOS-4049) Is this needed in there, can't we just show and hide this whole view?
    public func toggleVisibility() {
        guard !UIAccessibility.isVoiceOverRunning else {
            return
        }

        isNavBarHidden.toggle()
        
        if isNavBarHidden {
            layer.sublayers?.remove(at: 0)
        }
        else {
            layer.insertSublayer(gradientLayer, at: 0)
        }
        
        dismissButton.isHidden = isNavBarHidden
        headerLabel.isHidden = isNavBarHidden
        participantCountLabel.isHidden = isNavBarHidden
        participantIcon.isHidden = isNavBarHidden
        timeLabel.isHidden = isNavBarHidden
    }
    
    public func updateContent(_ contentUpdate: GroupCallNavigationBarContentUpdate) {
        Task { @MainActor in
            headerLabel.text = contentUpdate.title ?? "-"
            participantCountLabel.text = "\(contentUpdate.participantCount ?? 0)"
            
            timeLabel.text = dependencies.groupCallDateFormatter.timeFormatted(contentUpdate.timeInterval)
            updateAccessibilityLabel(timeInterval: contentUpdate.timeInterval)
        }
    }
    
    public func accessibilityElements() -> [Any] {
        [dismissButton, headerLabel]
    }
    
    // MARK: - Private Functions
    
    private func configureView() {
        addSubview(dismissButton)
        
        addSubview(headerLabel)
        addSubview(timeLabel)
        
        addSubview(participantIcon)
        addSubview(participantCountLabel)
        
        layer.insertSublayer(gradientLayer, at: 0)

        NSLayoutConstraint.activate([
            // Not really needed but to have at least a basic navigation bar height
            heightAnchor.constraint(greaterThanOrEqualToConstant: 30),
            
            dismissButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 4),
            dismissButton.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 4),
            
            headerLabel.centerYAnchor.constraint(equalTo: dismissButton.centerYAnchor),
            headerLabel.leadingAnchor.constraint(equalTo: dismissButton.trailingAnchor),
                        
            timeLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 2),
            timeLabel.leadingAnchor.constraint(equalTo: headerLabel.leadingAnchor),
            timeLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -10),
            
            participantIcon.firstBaselineAnchor.constraint(equalTo: participantCountLabel.firstBaselineAnchor),
            
            // Needed for long group names
            participantIcon.leadingAnchor.constraint(greaterThanOrEqualTo: headerLabel.trailingAnchor, constant: 8),

            participantCountLabel.centerYAnchor.constraint(equalTo: headerLabel.centerYAnchor),
            participantCountLabel.leadingAnchor.constraint(equalTo: participantIcon.trailingAnchor, constant: 2),
            participantCountLabel.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
        ])
    }
    
    private func updateAccessibilityLabel(timeInterval: TimeInterval) {
        let timeString = dependencies.groupCallDateFormatter
            .accessibilityString(
                at: timeInterval,
                with: "duration"
            )
        let participantsLocalizedString = dependencies.groupCallBundleUtil
            .localizedString(for: "group_call_participants_title")
        let participantsString = String(format: participantsLocalizedString, participantCountLabel.text ?? "1")
        headerLabel.accessibilityLabel = "\(headerLabel.text ?? ""), \(participantsString), \(timeString)"
    }
}
