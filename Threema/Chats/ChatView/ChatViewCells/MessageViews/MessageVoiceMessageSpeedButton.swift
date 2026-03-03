//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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

import CocoaLumberjackSwift
import Foundation
import UIKit

/// Shows either a microphone icon or the current voice message playback speed indicated by usersettings
/// Its width will not change.
final class MessageVoiceMessageSpeedButton: ThemedCodeButton {
    typealias config = ChatViewConfiguration.VoiceMessage.SpeedButton

    // MARK: - Internal Properties

    var isPlaying: Bool? {
        didSet {
            DispatchQueue.main.async {
                self.toggleOrUpdateView()
            }
        }
    }
    
    /// If a voice message is not consumed, it will show a badge on the mic icon
    var isConsumed: Bool? {
        didSet {
            DispatchQueue.main.async {
                self.updateMicrophoneIcon()
            }
        }
    }

    private func setupTraitRegistration() {
        let traits: [UITrait] = [UITraitUserInterfaceStyle.self]
        registerForTraitChanges(traits) { [weak self] (_: Self, previous) in
            guard let self else {
                return
            }
            if previous.userInterfaceStyle != traitCollection.userInterfaceStyle {
                toggleOrUpdateView()
            }
        }
    }

    // MARK: - Views
    
    private lazy var speedLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        
        label.textAlignment = .center
        
        label.isUserInteractionEnabled = true
        
        label.font = config.SpeedLabel.font
        label.textColor = .labelInverted

        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        return label
    }()
        
    private lazy var speedLabelContainer: UIView = {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.layer.cornerRadius = config.cornerRadius
        container.layer.cornerCurve = .continuous
            
        container.isUserInteractionEnabled = false

        container.addSubview(speedLabel)
            
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: speedLabel.topAnchor, constant: -config.topBottomInset),
            container.leadingAnchor.constraint(equalTo: speedLabel.leadingAnchor, constant: -config.leftRightInset),
            container.bottomAnchor.constraint(equalTo: speedLabel.bottomAnchor, constant: config.topBottomInset),
            container.trailingAnchor.constraint(equalTo: speedLabel.trailingAnchor, constant: config.leftRightInset),
        ])
        
        container.backgroundColor = .secondaryLabel

        container.alpha = 0.0
            
        return container
    }()
    
    // MARK: - Configuration Functions

    override init(frame: CGRect = .zero, action: @escaping ThemedCodeButton.Action) {
        super.init(frame: frame, action: action)
        setupTraitRegistration()
    }

    override func configureButton() {
        super.configureButton()
        
        addSubview(speedLabelContainer)
        
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: speedLabelContainer.topAnchor),
            leadingAnchor.constraint(equalTo: speedLabelContainer.leadingAnchor),
            bottomAnchor.constraint(equalTo: speedLabelContainer.bottomAnchor),
            trailingAnchor.constraint(equalTo: speedLabelContainer.trailingAnchor),
        ])

        /// This could be accessed through the `BusinessInjector` but at the moment there is no reason to
        let currentSpeed = UserSettings.shared().threemaAudioMessagePlaySpeedCurrentValue()
        speedLabel.text = "\(currentSpeed)x"
        
        updateMicrophoneIcon()
        
        /// We redispatch this on the main thread to avoid layouting too early causing temporary constraints due to a
        /// call to layoutIfNeeded when accessing the imageview of UIButton.
        DispatchQueue.main.async {
            self.toggleOrUpdateView(animated: false)
        }
    }
    
    // MARK: - Update Functions
    
    func toggleOrUpdateView(animated: Bool = true) {
        if let isPlaying, !isPlaying || self.isPlaying == nil {
            hideSpeedButton(animated: animated)
        }
        else {
            showAndUpdateSpeedButton(animated: animated)
        }
    }
    
    func updateMicrophoneIcon() {
        guard isConsumed ?? true else {
            let image = UIImage(
                resource: .threemaMicFillBadge
            ).applying(
                configuration: UIImage.SymbolConfiguration(scale: config.micIconSymbolConfigurationScale),
                paletteColors: [.tintColor, .secondaryLabel, .secondaryLabel]
            )
            
            setImage(image, for: .normal)
            return
        }
        
        let image = UIImage(
            systemName: "mic.fill"
        )?.applying(
            configuration: UIImage.SymbolConfiguration(scale: config.micIconSymbolConfigurationScale),
            paletteColors: [.secondaryLabel]
        )
        
        setImage(image, for: .normal)
    }
    
    private func hideSpeedButton(animated: Bool = true) {
        let change = {
            self.imageView?.alpha = 1
            self.speedLabelContainer.alpha = 0
            self.isUserInteractionEnabled = false
        }
        
        if animated {
            UIView.animate(
                withDuration: config.hideOrShowAnimationDuration,
                delay: 0.0,
                options: config.hideOrShowAnimationOptions,
                animations: change
            )
        }
        else {
            change()
        }
    }
    
    private func showAndUpdateSpeedButton(animated: Bool = true) {
        let currentSpeed = UserSettings.shared().threemaAudioMessagePlaySpeedCurrentValue()
        speedLabel.text = "\(currentSpeed)x"
        
        let change = {
            self.imageView?.alpha = 0
            self.speedLabelContainer.alpha = 1
            self.isUserInteractionEnabled = true
        }
        
        if animated {
            UIView.animate(
                withDuration: config.hideOrShowAnimationDuration,
                delay: 0.0,
                options: config.hideOrShowAnimationOptions,
                animations: change
            )
        }
        else {
            change()
        }
        
        accessibilityLabel = "\(currentSpeed)"
    }
}
