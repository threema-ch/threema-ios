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

import AVKit
import Foundation
import UIKit
import WebRTC

class GroupCallAudioOutputButton: UIButton {
    
    private typealias buttonConfig = GroupCallUIConfiguration.ToolbarButton
    private var dependencies: Dependencies
    
    private lazy var routePickerView: AVRoutePickerView = {
        let routePickerView = AVRoutePickerView(frame: CGRect(
            x: 0.0,
            y: 0.0,
            width: frame.size.width,
            height: frame.size.height
        ))
        
        routePickerView.translatesAutoresizingMaskIntoConstraints = false
        routePickerView.activeTintColor = UIColor.clear
        routePickerView.tintColor = UIColor.clear
        routePickerView.isOpaque = true
        routePickerView.alpha = 1.0
        
        routePickerView.prioritizesVideoDevices = true
        
        routePickerView.delegate = self
        
        // This hides the blinking of the symbol
        let button = routePickerView.subviews.compactMap { $0 as? UIButton }.first
        button?.layer.sublayers?.first?.isHidden = true
        
        return routePickerView
    }()
    
    // MARK: - Lifecycle
    
    init(frame: CGRect, dependencies: Dependencies) {
        self.dependencies = dependencies
        
        super.init(frame: frame)
        
        configureButton()
        proximitySensor(enable: true)
        registerObserver()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        Task { @MainActor in
            UIDevice.current.isProximityMonitoringEnabled = false
        }
    }
    
    // MARK: - Configuration
    
    private func configureButton() {
        
        let initialConfig = UIButton.Configuration.plain()
        configuration = updateConfig(config: initialConfig)
        
        layer.masksToBounds = true
        layer.cornerRadius = buttonConfig.smallerButtonCornerRadius
        clipsToBounds = true
        tintColor = buttonConfig.smallerButtonTint
        backgroundColor = buttonConfig.smallerButtonBackground
        translatesAutoresizingMaskIntoConstraints = false
        accessibilityLabel = dependencies.groupCallBundleUtil
            .localizedString(for: "group_call_accessibility_audio_output")
        
        addSubview(routePickerView)
        
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: buttonConfig.smallerButtonWidth),
            heightAnchor.constraint(equalTo: widthAnchor),
            routePickerView.widthAnchor.constraint(equalTo: widthAnchor),
            routePickerView.heightAnchor.constraint(equalTo: widthAnchor),
        ])
        
        configurationUpdateHandler = { [weak self] button in
            guard let self else {
                return
            }
            guard let config = button.configuration else {
                configuration = nil
                return
            }
            
            configuration = updateConfig(config: config)
        }
    }
    
    private func registerObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioSessionRouteChanged),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    // MARK: - Notifications
    
    @objc private func audioSessionRouteChanged() {
        Task { @MainActor in
            self.setNeedsUpdateConfiguration()
        }
    }
    
    // MARK: - Private Functions
    
    private func updateConfig(config: UIButton.Configuration) -> UIButton.Configuration {
        var newConfig = config
        
        for output in AVAudioSession.sharedInstance().currentRoute.outputs {
            switch output.portType {
            case .builtInSpeaker:
                newConfig.image = UIImage(
                    systemName: "speaker.wave.3",
                    withConfiguration: buttonConfig.smallerButtonImageConfig
                )
                proximitySensor(enable: false)
                
            case .headphones, .bluetoothLE, .bluetoothHFP, .bluetoothA2DP:
                newConfig.image = UIImage(
                    systemName: "earbuds",
                    withConfiguration: buttonConfig.smallerButtonImageConfig
                )
                proximitySensor(enable: false)
                
            case .builtInReceiver:
                newConfig.image = UIImage(
                    systemName: "ear.and.waveform",
                    withConfiguration: buttonConfig.smallerButtonImageConfig
                )
                proximitySensor(enable: true)
                
            default:
                newConfig.image = UIImage(
                    systemName: "speaker.wave.3",
                    withConfiguration: buttonConfig.smallerButtonImageConfig
                )
                proximitySensor(enable: false)
            }
        }
        
        return newConfig
    }

    private func proximitySensor(enable: Bool) {
        Task { @MainActor in
            UIDevice.current.isProximityMonitoringEnabled = enable
        }
    }
}

// MARK: - AVRoutePickerViewDelegate

extension GroupCallAudioOutputButton: AVRoutePickerViewDelegate {
    nonisolated func routePickerViewDidEndPresentingRoutes(_ routePickerView: AVRoutePickerView) {
        Task {
            await setNeedsUpdateConfiguration()
        }
    }
}
