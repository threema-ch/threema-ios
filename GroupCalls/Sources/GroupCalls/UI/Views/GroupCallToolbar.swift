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

class GroupCallToolbar: UIView {
    
    // MARK: - Subviews

    private lazy var audioOutputButton = GroupCallAudioOutputButton()
    
    private lazy var toggleAudioButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(
            systemName: "mic.slash",
            withConfiguration: GroupCallUIConfiguration.ToolbarButton.buttonImageConfig
        )
        
        let action = UIAction { [weak self] _ in
            self?.didTapToggleAudioButton()
        }
        
        let button = UIButton(configuration: configuration, primaryAction: action)
        
        button.layer.masksToBounds = true
        button.layer.cornerRadius = GroupCallUIConfiguration.ToolbarButton.cornerRadius
        button.clipsToBounds = true

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: GroupCallUIConfiguration.ToolbarButton.borderedButtonWidth),
            button.heightAnchor.constraint(equalTo: button.widthAnchor),
        ])
        
        button.configurationUpdateHandler = { [weak self] button in
            guard let self else {
                return
            }
            
            var config = button.configuration
            
            switch self.viewModel.ownAudioMuteState {
            case .changing:
                config?.showsActivityIndicator = true

            case .muted:
                config?.showsActivityIndicator = false
                config?.image = UIImage(
                    systemName: "mic.slash.fill",
                    withConfiguration: GroupCallUIConfiguration.ToolbarButton.buttonImageConfig
                )
                button.tintColor = .black
                button.backgroundColor = .white.withAlphaComponent(0.8)
                
            case .unmuted:
                config?.showsActivityIndicator = false
                config?.image = UIImage(
                    systemName: "mic.slash",
                    withConfiguration: GroupCallUIConfiguration.ToolbarButton.buttonImageConfig
                )
                button.tintColor = .white
                button.backgroundColor = .lightGray.withAlphaComponent(0.8)
            }
            button.configuration = config
        }
        
        return button
    }()
    
    private lazy var endCallButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.image = UIImage(
            systemName: "phone.down.fill",
            withConfiguration: GroupCallUIConfiguration.ToolbarButton.buttonImageConfig
        )
        
        let action = UIAction { [weak self] _ in
            self?.didTapEndCallButton()
        }
        
        let button = UIButton(configuration: configuration, primaryAction: action)
        
        button.layer.masksToBounds = true
        button.layer.cornerRadius = GroupCallUIConfiguration.ToolbarButton.cornerRadius
        button.clipsToBounds = true
        
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: GroupCallUIConfiguration.ToolbarButton.borderedButtonWidth),
            button.heightAnchor.constraint(equalTo: button.widthAnchor),
        ])
        
        return button
    }()
    
    private lazy var toggleVideoButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(
            systemName: "eye.slash",
            withConfiguration: GroupCallUIConfiguration.ToolbarButton.buttonImageConfig
        )
        
        let action = UIAction { [weak self] _ in
            self?.didTapToggleVideoButton()
        }
        
        let button = UIButton(configuration: configuration, primaryAction: action)
        button.backgroundColor = .white.withAlphaComponent(0.8)

        button.layer.masksToBounds = true
        button.layer.cornerRadius = GroupCallUIConfiguration.ToolbarButton.cornerRadius
        button.clipsToBounds = true
        
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: GroupCallUIConfiguration.ToolbarButton.borderedButtonWidth),
            button.heightAnchor.constraint(equalTo: button.widthAnchor),
        ])
        
        button.configurationUpdateHandler = { [weak self] button in
            guard let self else {
                return
            }
            
            var config = button.configuration
            
            switch self.viewModel.ownVideoMuteState {
            case .changing:
                config?.showsActivityIndicator = true

            case .muted:
                config?.showsActivityIndicator = false
                config?.image = UIImage(
                    systemName: "eye.slash",
                    withConfiguration: GroupCallUIConfiguration.ToolbarButton.buttonImageConfig
                )
                button.tintColor = .black
                button.backgroundColor = .white.withAlphaComponent(0.8)
                
            case .unmuted:
                config?.showsActivityIndicator = false
                config?.image = UIImage(
                    systemName: "eye.slash.fill",
                    withConfiguration: GroupCallUIConfiguration.ToolbarButton.buttonImageConfig
                )
                button.tintColor = .white
                button.backgroundColor = .lightGray.withAlphaComponent(0.8)
            }
            button.configuration = config
        }
        
        return button
    }()
    
    private lazy var switchCameraButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(
            systemName: "arrow.triangle.2.circlepath.camera.fill",
            withConfiguration: GroupCallUIConfiguration.ToolbarButton.buttonImageConfig
        )
        
        let action = UIAction { [weak self] _ in
            self?.didTapSwitchCamera()
        }
        
        let button = UIButton(configuration: configuration, primaryAction: action)
        button.tintColor = .white
        
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: GroupCallUIConfiguration.ToolbarButton.buttonWidth),
            button.heightAnchor.constraint(equalTo: button.widthAnchor),
        ])
        
        button.configurationUpdateHandler = { [weak self] button in
            guard let self else {
                return
            }
            
            button.isEnabled = self.viewModel.ownVideoMuteState != .muted
        }
        
        return button
    }()
    
    private lazy var toolbarStackView: UIStackView = {
        let stackView =
            UIStackView(arrangedSubviews: [
                toggleVideoButton,
                switchCameraButton,
                endCallButton,
                audioOutputButton,
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
    
    private weak var groupCallViewControllerDelegate: GroupCallViewControllerDelegate?
    
    private lazy var bottomInsetConstant: CGFloat = {
        if UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0 > 0 {
            return 0.0
        }
        return GroupCallUIConfiguration.Toolbar.inset
    }()
    
    // MARK: - Lifecycle

    init(
        viewModel: GroupCallViewModel,
        groupCallViewControllerDelegate: GroupCallViewControllerDelegate,
        dependencies: Dependencies
    ) {
        self.viewModel = viewModel
        self.groupCallViewControllerDelegate = groupCallViewControllerDelegate
        self.dependencies = dependencies
        super.init(frame: .zero)
        
        self.viewModel.toolBarDelegate = self
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
            toolbarStackView.topAnchor.constraint(
                equalTo: topAnchor,
                constant: GroupCallUIConfiguration.Toolbar.topInset
            ),
            toolbarStackView.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: GroupCallUIConfiguration.Toolbar.inset
            ),
            toolbarStackView.bottomAnchor.constraint(
                equalTo: safeAreaLayoutGuide.bottomAnchor,
                constant: -bottomInsetConstant
            ),
            toolbarStackView.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -GroupCallUIConfiguration.Toolbar.inset
            ),
            toolbarStackView.heightAnchor
                .constraint(equalToConstant: GroupCallUIConfiguration.ToolbarButton.borderedButtonWidth),
        ])
    }
    
    override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        gradientLayer.frame = bounds
    }
    
    public func toggleVisibility() {
        isToolbarHidden.toggle()
        
        if isToolbarHidden {
            layer.sublayers?.remove(at: 0)
            toolbarStackView.insertArrangedSubview(spacerView, at: 0)
            
            toolbarStackView.removeArrangedSubview(toggleVideoButton)
            toggleVideoButton.removeFromSuperview()
            toolbarStackView.removeArrangedSubview(endCallButton)
            endCallButton.removeFromSuperview()
            toolbarStackView.removeArrangedSubview(switchCameraButton)
            switchCameraButton.removeFromSuperview()
            toolbarStackView.removeArrangedSubview(audioOutputButton)
            audioOutputButton.removeFromSuperview()
        }
        else {
            layer.insertSublayer(gradientLayer, at: 0)
            
            toolbarStackView.removeArrangedSubview(spacerView)
            spacerView.removeFromSuperview()
            toolbarStackView.insertArrangedSubview(audioOutputButton, at: 0)
            toolbarStackView.insertArrangedSubview(endCallButton, at: 0)
            toolbarStackView.insertArrangedSubview(switchCameraButton, at: 0)
            toolbarStackView.insertArrangedSubview(toggleVideoButton, at: 0)
        }
    }
    
    // MARK: - Button Config Updates
    
    private func didTapToggleAudioButton() {
        Task {
            do {
                try await viewModel.toggleOwnAudio()
            }
            catch {
                // TODO: Test
            }
        }
    }
    
    private func didTapEndCallButton() {
        viewModel.endCall()
        Task { @MainActor in
            await groupCallViewControllerDelegate?.dismiss()
        }
    }
    
    private func didTapToggleVideoButton() {
        Task {
            do {
                try await viewModel.toggleOwnVideo()
            }
            catch {
                // TODO: Test
            }
        }
    }
    
    private func didTapSwitchCamera() {
        Task {
            await viewModel.switchCamera()
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
