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

class GroupCallToolbar: UIView {
    typealias toolbarConfig = GroupCallUIConfiguration.Toolbar
    typealias toolbarButtonConfig = GroupCallUIConfiguration.ToolbarButton
    
    // MARK: - Subviews

    // MARK: Toggle Video Button

    private lazy var toggleVideoButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = dependencies.groupCallBundleUtil.image(named: "threema.video.outline.slash")
            .withConfiguration(toolbarButtonConfig.biggerButtonImageConfig)
        let action = UIAction { [weak self] _ in
            self?.didTapToggleVideoButton()
        }
        configuration.activityIndicatorColorTransformer = .grayscale
        
        let button = UIButton(configuration: configuration, primaryAction: action)
        
        button.layer.masksToBounds = true
        button.layer.cornerRadius = toolbarButtonConfig.biggerButtonCornerRadius
        button.clipsToBounds = true
        button.tintColor = toolbarButtonConfig.biggerButtonTint
        button.backgroundColor = toolbarButtonConfig.biggerButtonBackground

        // TODO: (IOS-4111) Remove? See comment in NotificationPresenterWrapper
        button.accessibilityTraits.insert(.startsMediaSession)
        
        button.accessibilityLabel = dependencies.groupCallBundleUtil
            .localizedString(for: "group_call_accessibility_enable_camera")

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: toolbarButtonConfig.biggerButtonWidth),
            button.heightAnchor.constraint(equalTo: button.widthAnchor),
        ])
        
        button.configurationUpdateHandler = { [weak self] button in
            guard let self else {
                return
            }
            
            var config = button.configuration
            
            switch viewModel.ownVideoMuteState {
            case .changing:
                button.accessibilityLabel = nil
                config?.showsActivityIndicator = true

            case .muted:
                button.accessibilityLabel = dependencies.groupCallBundleUtil
                    .localizedString(for: "group_call_accessibility_enable_camera")
                config?.showsActivityIndicator = false
                config?.image = dependencies.groupCallBundleUtil.image(named: "threema.video.outline.slash")
                    .withConfiguration(toolbarButtonConfig.biggerButtonImageConfig)
                
            case .unmuted:
                button.accessibilityLabel = dependencies.groupCallBundleUtil
                    .localizedString(for: "group_call_accessibility_disable_camera")
                config?.showsActivityIndicator = false
                config?.image = dependencies.groupCallBundleUtil.image(named: "threema.video.outline")
                    .withConfiguration(toolbarButtonConfig.biggerButtonImageConfig)
            }
            button.configuration = config
        }
        
        return button
    }()
    
    // MARK: Switch Camera Button

    private lazy var switchCameraButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(
            systemName: "arrow.triangle.2.circlepath.camera",
            withConfiguration: toolbarButtonConfig.smallerButtonImageConfig
        )
        
        let action = UIAction { [weak self] _ in
            self?.didTapSwitchCamera()
        }
        
        let button = UIButton(configuration: configuration, primaryAction: action)
        button.layer.masksToBounds = true
        button.layer.cornerRadius = toolbarButtonConfig.smallerButtonCornerRadius
        button.clipsToBounds = true
        button.tintColor = toolbarButtonConfig.smallerButtonTint
        button.backgroundColor = toolbarButtonConfig.smallerButtonBackground
        button.accessibilityLabel = dependencies.groupCallBundleUtil
            .localizedString(for: "call_camera_switch_to_back_button")

        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: toolbarButtonConfig.smallerButtonWidth),
            button.heightAnchor.constraint(equalTo: button.widthAnchor),
        ])
        
        button.configurationUpdateHandler = { [weak self] button in
            guard let self else {
                return
            }
            button.isHidden = viewModel.ownVideoMuteState == .muted
            button.tintColor = toolbarButtonConfig.smallerButtonTint
            button.backgroundColor = toolbarButtonConfig.smallerButtonBackground
        }
        
        return button
    }()
    
    private lazy var switchCameraButtonView: UIView = {
        let view = UIView()
        view.addSubview(switchCameraButton)
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: toolbarButtonConfig.biggerButtonWidth),
            switchCameraButton.centerXAnchor.constraint(
                equalTo: view.centerXAnchor,
                constant: -toolbarButtonConfig.smallerButtonOffset
            ),
            switchCameraButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        
        return view
    }()
    
    // MARK: Leave Call Button

    private lazy var leaveCallButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.image = UIImage(
            systemName: "phone.down.fill",
            withConfiguration: toolbarButtonConfig.biggerButtonImageConfig
        )
        
        let action = UIAction { [weak self] _ in
            self?.viewModel.leaveCallButtonTapped()
        }
        
        let button = UIButton(configuration: configuration, primaryAction: action)
        
        button.layer.masksToBounds = true
        button.layer.cornerRadius = toolbarButtonConfig.biggerButtonCornerRadius
        button.clipsToBounds = true
        button.tintColor = .red
        button.accessibilityIdentifier = "group_call_button_hangup"
        
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: toolbarButtonConfig.biggerButtonWidth),
            button.heightAnchor.constraint(equalTo: button.widthAnchor),
        ])
        
        return button
    }()
    
    // MARK: Audio Output Button

    private lazy var audioOutputButton = GroupCallAudioOutputButton(frame: .zero, dependencies: dependencies)
    private lazy var audioOutputButtonView: UIView = {
        let view = UIView()
        view.addSubview(audioOutputButton)
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: toolbarButtonConfig.biggerButtonWidth),
            audioOutputButton.centerXAnchor.constraint(
                equalTo: view.centerXAnchor,
                constant: toolbarButtonConfig.smallerButtonOffset
            ),
            audioOutputButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
                
        return view
    }()

    // MARK: Toggle Audio Button

    private lazy var toggleAudioButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(
            systemName: "mic.slash",
            withConfiguration: toolbarButtonConfig.biggerButtonImageConfig
        )
        configuration.activityIndicatorColorTransformer = .grayscale
        
        let action = UIAction { [weak self] _ in
            self?.didTapToggleAudioButton()
        }
        
        let button = UIButton(configuration: configuration, primaryAction: action)
        
        button.layer.masksToBounds = true
        button.layer.cornerRadius = toolbarButtonConfig.biggerButtonCornerRadius
        button.clipsToBounds = true
        button.tintColor = toolbarButtonConfig.biggerButtonTint
        button.backgroundColor = toolbarButtonConfig.biggerButtonBackground
        button.accessibilityLabel = dependencies.groupCallBundleUtil
            .localizedString(for: "group_call_accessibility_enable_microphone")
        
        // TODO: (IOS-4111) Remove? See comment in NotificationPresenterWrapper
        button.accessibilityTraits.insert(.startsMediaSession)

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: toolbarButtonConfig.biggerButtonWidth),
            button.heightAnchor.constraint(equalTo: button.widthAnchor),
        ])
        
        button.configurationUpdateHandler = { [weak self] button in
            guard let self else {
                return
            }
            
            var config = button.configuration
            
            switch viewModel.ownAudioMuteState {
            case .changing:
                button.accessibilityLabel = nil
                config?.showsActivityIndicator = true
                
            case .muted:
                button.accessibilityLabel = dependencies.groupCallBundleUtil
                    .localizedString(for: "group_call_accessibility_enable_microphone")
                config?.showsActivityIndicator = false
                config?.image = UIImage(
                    systemName: "mic.slash",
                    withConfiguration: toolbarButtonConfig.biggerButtonImageConfig
                )

            case .unmuted:
                button.accessibilityLabel = dependencies.groupCallBundleUtil
                    .localizedString(for: "group_call_accessibility_disable_microphone")
                config?.showsActivityIndicator = false
                config?.image = UIImage(
                    systemName: "mic",
                    withConfiguration: toolbarButtonConfig.biggerButtonImageConfig
                )
            }
            button.configuration = config
        }
        
        return button
    }()

    private lazy var toolbarStackView: UIStackView = {
        let stackView =
            UIStackView(arrangedSubviews: [
                toggleVideoButton,
                switchCameraButtonView,
                leaveCallButton,
                audioOutputButtonView,
                toggleAudioButton,
            ])
        
        stackView.distribution = .equalSpacing
        stackView.isUserInteractionEnabled = true
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        return stackView
    }()
    
    private lazy var spacerView: UIView = {
        let spacerView = UIView()
        
        let spacerViewWidthConstraint = spacerView.widthAnchor.constraint(equalToConstant: .greatestFiniteMagnitude)
        spacerViewWidthConstraint.priority = .defaultLow
        spacerViewWidthConstraint.isActive = true
        
        return spacerView
    }()
    
    private lazy var gradientLayer: CAGradientLayer = {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.black.withAlphaComponent(0).cgColor,
            UIColor.black.withAlphaComponent(GroupCallUIConfiguration.General.initialGradientOpacity).cgColor,
        ]
        
        gradientLayer.frame = bounds
        return gradientLayer
    }()
    
    // MARK: - Internal Properties
    
    private var viewModel: GroupCallViewModel
    private var dependencies: Dependencies
    
    private var isSpeaker = false
    private var isToolbarHidden = false
    
    // MARK: - Lifecycle

    init(
        viewModel: GroupCallViewModel,
        dependencies: Dependencies
    ) {
        self.viewModel = viewModel
        self.dependencies = dependencies
        
        super.init(frame: .zero)
        
        self.viewModel.setToolBarDelegate(self)
        setup()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        addSubview(toolbarStackView)
        
        layer.insertSublayer(gradientLayer, at: 0)
        
        NSLayoutConstraint.activate([
            switchCameraButtonView.topAnchor.constraint(equalTo: toolbarStackView.topAnchor),
            switchCameraButtonView.bottomAnchor.constraint(equalTo: toolbarStackView.bottomAnchor),
            
            audioOutputButtonView.topAnchor.constraint(equalTo: toolbarStackView.topAnchor),
            audioOutputButtonView.bottomAnchor.constraint(equalTo: toolbarStackView.bottomAnchor),

            toolbarStackView.topAnchor.constraint(
                equalTo: topAnchor,
                constant: toolbarConfig.verticalInset
            ),
            toolbarStackView.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: toolbarConfig.horizontalInset
            ),
            toolbarStackView.bottomAnchor.constraint(
                equalTo: safeAreaLayoutGuide.bottomAnchor,
                constant: -toolbarConfig.verticalInset
            ),
            toolbarStackView.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -toolbarConfig.horizontalInset
            ),
            toolbarStackView.heightAnchor
                .constraint(equalToConstant: toolbarButtonConfig.biggerButtonWidth),
        ])
    }
    
    override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        gradientLayer.frame = bounds
    }
    
    public func toggleVisibility() {
        guard !UIAccessibility.isVoiceOverRunning else {
            return
        }
        isToolbarHidden.toggle()
        
        if isToolbarHidden {
            layer.sublayers?.remove(at: 0)
            toolbarStackView.insertArrangedSubview(spacerView, at: 0)
            
            toolbarStackView.removeArrangedSubview(toggleVideoButton)
            toggleVideoButton.removeFromSuperview()
            toolbarStackView.removeArrangedSubview(leaveCallButton)
            leaveCallButton.removeFromSuperview()
            toolbarStackView.removeArrangedSubview(switchCameraButtonView)
            switchCameraButtonView.removeFromSuperview()
            toolbarStackView.removeArrangedSubview(audioOutputButtonView)
            audioOutputButtonView.removeFromSuperview()
        }
        else {
            layer.insertSublayer(gradientLayer, at: 0)
            
            toolbarStackView.removeArrangedSubview(spacerView)
            spacerView.removeFromSuperview()
            toolbarStackView.insertArrangedSubview(audioOutputButtonView, at: 0)
            toolbarStackView.insertArrangedSubview(leaveCallButton, at: 0)
            toolbarStackView.insertArrangedSubview(switchCameraButtonView, at: 0)
            toolbarStackView.insertArrangedSubview(toggleVideoButton, at: 0)
        }
    }
    
    // MARK: - Public Functions
       
    public func accessibilityElements() -> [Any] {
        [toggleVideoButton, switchCameraButton, leaveCallButton, audioOutputButton, toggleAudioButton]
    }
    
    public func magicTapToggle() {
        didTapToggleAudioButton()
    }
    
    // MARK: - Button Config Updates
    
    private func didTapToggleAudioButton() {
        Task {
            await viewModel.toggleOwnAudio()
        }
    }
    
    private func didTapToggleVideoButton() {
        Task {
            await viewModel.toggleOwnVideo()
        }
    }
    
    private func didTapSwitchCamera() {
        Task {
            await viewModel.switchCamera()
            if await viewModel.groupCallActor?.currentCameraPosition == .front {
                switchCameraButton.accessibilityLabel = dependencies.groupCallBundleUtil
                    .localizedString(for: "call_camera_switch_to_back_button")
            }
            else {
                switchCameraButton.accessibilityLabel = dependencies.groupCallBundleUtil
                    .localizedString(for: "call_camera_switch_to_front_button")
            }
        }
    }
}

// MARK: - GroupCallToolbarDelegate

extension GroupCallToolbar: GroupCallToolbarDelegate {
    nonisolated func updateToggleAudioButton() {
        Task { @MainActor in
            toggleAudioButton.setNeedsUpdateConfiguration()
        }
    }
    
    nonisolated func updateToggleVideoButton() {
        Task { @MainActor in
            toggleVideoButton.setNeedsUpdateConfiguration()
            switchCameraButton.setNeedsUpdateConfiguration()
        }
    }
}
