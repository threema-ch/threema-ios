import AVKit
import Foundation
import UIKit
import WebRTC

final class GroupCallAudioOutputButton: UIButton {
    
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
        
        var initialConfig: UIButton.Configuration =
            if #available(iOS 26.0, *) {
                .glass()
            }
            else {
                .bordered()
            }
        initialConfig.cornerStyle = .capsule

        // Add some color pre glass
        if #unavailable(iOS 26.0) {
            initialConfig.baseForegroundColor = buttonConfig.smallerButtonTint
            initialConfig.baseBackgroundColor = buttonConfig.smallerButtonBackground
        }
        
        configuration = updateConfig(config: initialConfig)
        
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
