//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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
        configuration.image = UIImage(
            systemName: "chevron.down",
            withConfiguration: GroupCallUIConfiguration.NavigationBar.buttonImageConfig
        )
        
        let action = UIAction { [weak self] _ in
            Task { @MainActor in
                await self?.groupCallViewControllerDelegate?.dismiss()
            }
        }
        
        let button = UIButton(configuration: configuration, primaryAction: action)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private var groupNameLabel: UILabel = {
        let groupNameLabel = UILabel()
        groupNameLabel.text = "-"
        groupNameLabel.textColor = .white
        groupNameLabel.font = UIFont.preferredFont(forTextStyle: GroupCallUIConfiguration.NavigationBar.textStyle)
        groupNameLabel.translatesAutoresizingMaskIntoConstraints = false
        return groupNameLabel
    }()
    
    private var participantCountLabel: UILabel = {
        let participantCountLabel = UILabel()
        participantCountLabel.text = "0"
        participantCountLabel.textColor = .white
        participantCountLabel.font = UIFont
            .preferredFont(forTextStyle: GroupCallUIConfiguration.NavigationBar.smallerTextStyle)
        participantCountLabel.translatesAutoresizingMaskIntoConstraints = false
        return participantCountLabel
    }()
    
    private var participantIcon: UIImageView = {
        let image = UIImage(
            systemName: "person.2.fill",
            withConfiguration: GroupCallUIConfiguration.NavigationBar.smallerImageConfig
        )
        
        let imageView = UIImageView(image: image)
        imageView.tintColor = .white
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private var timeLabel: UILabel = {
        let timeLabel = UILabel()
        timeLabel.text = "0:00"
        timeLabel.textColor = .white
        timeLabel.font = UIFont.preferredFont(forTextStyle: GroupCallUIConfiguration.NavigationBar.smallerTextStyle)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        return timeLabel
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

    // MARK: - Lifecycle

    init(groupCallViewControllerDelegate: GroupCallViewControllerDelegate) {
        self.groupCallViewControllerDelegate = groupCallViewControllerDelegate
        
        super.init(frame: .zero)
        
        setup()
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
    
    public func toggleVisibility() {
        isNavBarHidden.toggle()
        
        if isNavBarHidden {
            layer.sublayers?.remove(at: 0)
        }
        else {
            layer.insertSublayer(gradientLayer, at: 0)
        }
        
        dismissButton.isHidden = isNavBarHidden
        groupNameLabel.isHidden = isNavBarHidden
        participantCountLabel.isHidden = isNavBarHidden
        participantIcon.isHidden = isNavBarHidden
        timeLabel.isHidden = isNavBarHidden
    }
    
    public func updateContent(_ contentUpdate: GroupCallNavigationBarContentUpdate) {
        Task { @MainActor in
            groupNameLabel.text = contentUpdate.title ?? "-"
            participantCountLabel.text = "\(contentUpdate.participantCount ?? 0)"
            timeLabel.text = contentUpdate.timeString ?? "0:00"
        }
    }
    
    // MARK: - Private Functions
    
    private func setup() {
        addSubview(dismissButton)
        addSubview(groupNameLabel)
        addSubview(participantIcon)
        addSubview(participantCountLabel)
        addSubview(timeLabel)
        
        layer.insertSublayer(gradientLayer, at: 0)

        NSLayoutConstraint.activate([
            dismissButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            dismissButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            
            timeLabel.topAnchor.constraint(equalTo: dismissButton.bottomAnchor),
            timeLabel.leadingAnchor.constraint(equalTo: groupNameLabel.leadingAnchor),
            timeLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),

            groupNameLabel.centerYAnchor.constraint(equalTo: dismissButton.centerYAnchor),
            groupNameLabel.leadingAnchor.constraint(equalTo: dismissButton.trailingAnchor),
            
            participantIcon.centerYAnchor.constraint(equalTo: dismissButton.centerYAnchor),
            participantIcon.trailingAnchor.constraint(equalTo: participantCountLabel.leadingAnchor, constant: -4),

            participantCountLabel.centerYAnchor.constraint(equalTo: dismissButton.centerYAnchor),
            participantCountLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
        ])
    }
}
