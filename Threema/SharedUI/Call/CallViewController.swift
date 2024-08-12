//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2024 Threema GmbH
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
import ThreemaFramework
import WebRTC

class CallViewController: UIViewController {
    @IBOutlet private var backgroundImage: UIImageView!
    @IBOutlet private var contentView: UIView!
    @IBOutlet private var contactLabel: UILabel!
    @IBOutlet private var verificationLevel: UIImageView!
    @IBOutlet private var debugLabel: UILabel!
    
    @IBOutlet private var acceptButton: UIButton!
    @IBOutlet private var rejectButton: UIButton!
    
    @IBOutlet private var hideButton: UIButton!
    @IBOutlet private var cellularWarningButton: UIButton!
    @IBOutlet private var timerLabel: UILabel!
    
    @IBOutlet private var localVideoView: UIView!
    @IBOutlet private var remoteVideoView: UIView!
    
    @IBOutlet var muteButton: UIButton!
    @IBOutlet var speakerButton: UIButton!
    @IBOutlet var endButton: UIButton!
    @IBOutlet var cameraButton: UIButton!
    @IBOutlet var cameraSwitchButton: UIButton!
        
    @IBOutlet var callInfoStackView: UIStackView!
    @IBOutlet var callInfoStackViewTopConstraint: NSLayoutConstraint!
    @IBOutlet var phoneButtonsStackView: UIStackView!
    @IBOutlet var phoneButtonsStackViewBottomConstraint: NSLayoutConstraint!
    
    @IBOutlet var localVideoViewConstraintHeight: NSLayoutConstraint!
    @IBOutlet var localVideoViewConstraintWidth: NSLayoutConstraint!
    
    @IBOutlet var localVideoViewConstraintLeft: NSLayoutConstraint!
    @IBOutlet var localVideoViewConstraintRight: NSLayoutConstraint!
    @IBOutlet var localVideoViewConstraintBottom: NSLayoutConstraint!
    @IBOutlet var localVideoViewConstraintBottomNavigation: NSLayoutConstraint!
    @IBOutlet var localVideoViewConstraintTop: NSLayoutConstraint!
    @IBOutlet var localVideoViewConstraintTopNavigation: NSLayoutConstraint!
    @IBOutlet var localVideoViewConstraintTopNavigationLabel: NSLayoutConstraint!
        
    @IBOutlet var phoneButtonsGradientView: UIView!
    @IBOutlet var callInfoGradientView: UIView!

    var contactIdentity: String? {
        didSet {
            let entityManager = EntityManager()
            contact = entityManager.entityFetcher.contact(for: contactIdentity)
        }
    }

    var alreadyAccepted = false
    var isCallInitiator = false
    var isTesting = false
    var viewWasHidden = false
    var threemaVideoCallAvailable = false
    var isLocalVideoActive = false
    var isReceivingRemoteVideo = false {
        didSet {
            if isReceivingRemoteVideo {
                startRemoteVideo()
                DispatchQueue.main.async {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.warning)
                }
            }
            else {
                endRemoteVideo()
            }
        }
    }

    var isRemoteVideoPortrait = false
    var shouldShowCellularCallWarning = false {
        didSet {
            DispatchQueue.main.async {
                if let warningButton = self.cellularWarningButton,
                   warningButton.isHidden == self.shouldShowCellularCallWarning {
                    warningButton.isHidden = !self.shouldShowCellularCallWarning
                    if self.shouldShowCellularCallWarning {
                        self.playCellularCallWarningSound()
                    }
                }
            }
        }
    }
    
    private var contact: ContactEntity?
    
    private var statsTimer: Timer?
    
    private var useBackCamera = false

    private var myVolumeView: UIView?
    
    private var didRotateDevice = false
    
    private var audioPlayer: AVAudioPlayer?
    
    private var audioRouteChangeObserver: NSObjectProtocol?
    private var enterForegroundObserver: NSObjectProtocol?

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
        
    deinit {
        if let audioObserver = audioRouteChangeObserver {
            NotificationCenter.default.removeObserver(audioObserver)
        }
        
        if let foregroundObserver = enterForegroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        modalPresentationCapturesStatusBarAppearance = true
        
        localVideoView.layer.cornerCurve = .continuous
        localVideoView.layer.cornerRadius = 16
        
        cellularWarningButton.isHidden = true
        
        audioRouteChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] n in
            guard let self else {
                return
            }
            let currentRoute = AVAudioSession.sharedInstance().currentRoute
            
            for output in currentRoute.outputs {
                if isBeingDismissed {
                    UIDevice.current.isProximityMonitoringEnabled = false
                }
                else {
                    if output.portType == AVAudioSession.Port.builtInReceiver {
                        if UserSettings.shared()?.disableProximityMonitoring == false,
                           !UIDevice.current.isProximityMonitoringEnabled,
                           VoIPCallStateManager.shared.currentCallState() != .idle {
                            UIDevice.current.isProximityMonitoringEnabled = true
                        }
                    }
                    else {
                        if UIDevice.current.isProximityMonitoringEnabled {
                            UIDevice.current.isProximityMonitoringEnabled = false
                        }
                    }
                }
                
                if output.portType == AVAudioSession.Port.builtInSpeaker {
                    let speakerImage = UIImage(systemName: "speaker.wave.2.circle.fill")?
                        .applying(
                            pointSize: 36.0,
                            symbolWeight: .thin,
                            symbolScale: .large,
                            paletteColors: [Colors.black, Colors.black, Colors.white]
                        )
                    speakerButton.setImage(
                        speakerImage,
                        for: .normal
                    )
                    speakerButton.setImage(
                        speakerImage,
                        for: .highlighted
                    )
                    speakerButton.setImage(
                        speakerImage,
                        for: .selected
                    )
                    speakerButton.tag = 1
                }
                else if output.portType == AVAudioSession.Port.headphones {
                    let headphonesImage = UIImage(systemName: "headphones.circle.fill")?
                        .applying(
                            pointSize: 36.0,
                            symbolWeight: .thin,
                            symbolScale: .large,
                            paletteColors: [Colors.black, Colors.black, Colors.white]
                        )
                    speakerButton.setImage(
                        headphonesImage,
                        for: .normal
                    )
                    speakerButton.setImage(
                        headphonesImage,
                        for: .highlighted
                    )
                    speakerButton.setImage(
                        headphonesImage,
                        for: .selected
                    )
                    speakerButton.tag = 2
                }
                else if output.portType == AVAudioSession.Port.bluetoothA2DP || output.portType == AVAudioSession.Port
                    .bluetoothHFP || output.portType == AVAudioSession.Port.bluetoothLE {
                    let bluetoothImage = UIImage(resource: .threemaBluetoothCircleFill)
                        .applying(
                            pointSize: 36.0,
                            symbolWeight: .thin,
                            symbolScale: .large,
                            paletteColors: [Colors.black, Colors.black, Colors.white]
                        )
                    speakerButton.setImage(
                        bluetoothImage,
                        for: .normal
                    )
                    speakerButton.setImage(
                        bluetoothImage,
                        for: .highlighted
                    )
                    speakerButton.setImage(
                        bluetoothImage,
                        for: .selected
                    )

                    speakerButton.tag = 3
                }
                else {
                    let earpeaceImage = UIImage(systemName: "speaker.wave.2.circle")?
                        .applying(
                            pointSize: 36.0,
                            symbolWeight: .thin,
                            symbolScale: .large,
                            paletteColors: [Colors.white, Colors.white, Colors.white]
                        )
                    speakerButton.setImage(
                        earpeaceImage,
                        for: .normal
                    )
                    speakerButton.setImage(
                        earpeaceImage,
                        for: .highlighted
                    )
                    speakerButton.setImage(
                        earpeaceImage,
                        for: .selected
                    )
                    speakerButton.tag = 0
                }
                updateAccessibilityLabels()
                
                guard let info = n.userInfo,
                      let value = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
                      let reason = AVAudioSession.RouteChangeReason(rawValue: value) else {
                    return
                }
                
                switch reason {
                case .newDeviceAvailable, .oldDeviceUnavailable:
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.checkAndHandleAvailableBluetoothDevices()
                    }
                default: break
                }
            }
        }
        
        enterForegroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [unowned self] _ in
            if !isNavigationVisible() {
                localVideoViewConstraintBottom.isActive = true
            }
        }
        
        #if DEBUG
            let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
            hideButton.addGestureRecognizer(longPressRecognizer)
        #endif
        
        let panGR = UIPanGestureRecognizer(target: self, action: #selector(didPan(gesture:)))
        localVideoView.addGestureRecognizer(panGR)
        
        let showHideNavigation = UITapGestureRecognizer(target: self, action: #selector(showHideNavigation(gesture:)))
        remoteVideoView.addGestureRecognizer(showHideNavigation)
        
        let switchVideoViews = UITapGestureRecognizer(target: self, action: #selector(switchVideoViews(gesture:)))
        localVideoView.addGestureRecognizer(switchVideoViews)
                
        updateConstraintsAfterRotation(size: CGSize(width: 80.0, height: 107.0))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
                
        NavigationBarPromptHandler.isCallActiveInBackground = false
        muteButton.isSelected = VoIPCallStateManager.shared.isCallMuted()
        if !isTesting {
            UIDevice.current
                .isProximityMonitoringEnabled = !(UserSettings.shared()?.disableProximityMonitoring ?? false)
        }
        UIApplication.shared.isIdleTimerDisabled = true
        setupView()
        updateAccessibilityLabels()
        
        if !isNavigationVisible() {
            moveLocalVideoViewToCorrectPosition(moveNavigation: true)
        }
        
        checkAndHandleAvailableBluetoothDevices()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        updateGradientBackground()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
                
        UIDevice.current.isProximityMonitoringEnabled = false
        
        if !NavigationBarPromptHandler.isWebActive {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        
        switch VoIPCallStateManager.shared.currentCallState() {
        case .ended, .remoteEnded, .rejected, .rejectedBusy, .rejectedTimeout, .rejectedDisabled, .rejectedOffHours,
             .rejectedUnknown, .microphoneDisabled:
            DispatchQueue.main.async {
                self.removeAllSubviewsFromVideoViews()
            }
        default:
            break
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        didRotateDevice = true
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if didRotateDevice {
            didRotateDevice = false
            updateGradientBackground()

            #if arch(arm64)
                if let rR = VoIPCallStateManager.shared.remoteVideoRenderer(),
                   let remoteRenderer = rR as? RTCMTLVideoView {
                    updateRemoteVideoContentMode(videoView: remoteRenderer)
                }
            #endif
        }
    }
        
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .all
    }
    
    override var shouldAutorotate: Bool {
        true
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }
}

extension CallViewController {
    // MARK: Public functions
    
    func voIPCallStatusChanged(state: VoIPCallService.CallState, oldState: VoIPCallService.CallState) {
        if isTesting == true {
            return
        }
        var timerString = ""
        switch state {
        case .idle:
            timerString = BundleUtil.localizedString(forKey: "call_status_wait_ringing")
        case .sendOffer:
            timerString = BundleUtil.localizedString(forKey: "call_status_wait_ringing")
        case .receivedOffer:
            timerString = BundleUtil.localizedString(forKey: "call_status_wait_ringing")
        case .outgoingRinging:
            timerString = BundleUtil.localizedString(forKey: "call_status_ringing")
        case .incomingRinging:
            timerString = BundleUtil.localizedString(forKey: "call_status_incom_ringing")
        case .sendAnswer:
            timerString = BundleUtil.localizedString(forKey: "call_status_ringing")
        case .receivedAnswer:
            timerString = BundleUtil.localizedString(forKey: "call_status_ringing")
        case .initializing:
            timerString = BundleUtil.localizedString(forKey: "call_status_initializing")
        case .calling:
            timerString = BundleUtil.localizedString(forKey: "call_status_calling")
        case .reconnecting:
            if oldState != .remoteEnded, oldState != .ended {
                timerString = BundleUtil.localizedString(forKey: "call_status_reconnecting")
            }
        case .ended, .remoteEnded:
            timerString = BundleUtil.localizedString(forKey: "call_end")
        case .rejected:
            timerString = BundleUtil.localizedString(forKey: "call_rejected")
        case .rejectedBusy:
            timerString = BundleUtil.localizedString(forKey: "call_rejected_busy")
        case .rejectedTimeout:
            timerString = BundleUtil.localizedString(forKey: "call_rejected_timeout")
        case .rejectedOffHours:
            timerString = BundleUtil.localizedString(forKey: "call_rejected")
        case .rejectedUnknown:
            timerString = BundleUtil.localizedString(forKey: "call_rejected")
        case .rejectedDisabled:
            timerString = BundleUtil.localizedString(forKey: "call_rejected_disabled")
        case .microphoneDisabled:
            timerString = BundleUtil.localizedString(forKey: "call_mic_access")
        }
        DispatchQueue.main.async {
            self.timerLabel?.text = timerString
            self.muteButton?.isEnabled = state == .calling || state == .reconnecting
        }
        
        updateView()
    }
    
    func voIPCallDurationChanged(_ time: Int) {
        DispatchQueue.main.async {
            if self.timerLabel != nil {
                self.timerLabel.text = DateFormatter.timeFormatted(time)
            }
        }
    }
    
    func startDebugMode(connection: RTCPeerConnection?) {
        guard let connection else {
            return
        }

        let dict = ["connection": connection]
        statsTimer?.invalidate()
        statsTimer = nil
        DispatchQueue.main.async {
            var previousState: VoIPStatsState?
            self.statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { _ in
                if let connection = dict["connection"] {
                    connection.statistics { report in
                        let options = VoIPStatsOptions()
                        options.selectedCandidatePair = true
                        options.transport = true
                        options.crypto = true
                        options.inboundRtp = true
                        options.outboundRtp = true
                        options.tracks = true
                        options.candidatePairsFlag = .OVERVIEW
                        let stats = VoIPStats(
                            report: report,
                            options: options,
                            transceivers: connection.transceivers,
                            previousState: previousState
                        )
                        previousState = stats.buildVoIPStatsState()
                        DispatchQueue.main.async {
                            if self.debugLabel != nil {
                                if self.debugLabel.isHidden == false {
                                    var statsString = stats.getShortRepresentation()
                                    if self.threemaVideoCallAvailable {
                                        statsString +=
                                            "\n\n\(CallsignalingProtocol.printDebugQualityProfiles(remoteProfile: VoIPCallStateManager.shared.remoteVideoQualityProfile(), networkIsRelayed: VoIPCallStateManager.shared.networkIsRelayed()))"
                                    }
                                    self.debugLabel.text = statsString
                                }
                            }
                        }
                    }
                }
            })
        }
    }
    
    func resetStatsTimer() {
        statsTimer?.invalidate()
        statsTimer = nil
        
        if let alert = presentedViewController as? UIAlertController {
            alert.dismiss(animated: false)
        }
    }
    
    func enableThreemaVideoCall() {
        DispatchQueue.main.async {
            self.threemaVideoCallAvailable = true
        }
    }
    
    func disableThreemaVideoCall() {
        DispatchQueue.main.async {
            self.threemaVideoCallAvailable = false
            self.endLocalVideo()
        }
    }
}

extension CallViewController {
    // MARK: Private functions
    
    private func setupView() {
        contactLabel.text = contact?.displayName
        
        backgroundImage.contentMode = contact?.isProfilePictureSet() ?? false ? .scaleAspectFill : .scaleAspectFit
        if let contact {
            setBackgroundForContact(contact: contact)
        }
        backgroundImage.backgroundColor = Colors.black
        verificationLevel.image = contact?.verificationLevelImage()

        if isTesting == false {
            debugLabel.isHidden = true
            
            updateView()
            timerLabel.isHidden = false
        }
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            speakerButton.isSelected = true
        }
                
        debugLabel.text = ""
        
        let acceptButtonImage = UIImage(systemName: "phone.circle.fill")?
            .applying(
                pointSize: 50.0,
                symbolWeight: .semibold,
                symbolScale: .large,
                paletteColors: [Colors.white, Colors.white, Colors.green]
            )
        acceptButton.setImage(acceptButtonImage, for: .normal)
        acceptButton.setImage(acceptButtonImage, for: .selected)
        acceptButton.setImage(acceptButtonImage, for: .highlighted)
        
        let rejectButtonImage = UIImage(systemName: "phone.down.circle.fill")?
            .applying(
                pointSize: 50.0,
                symbolWeight: .semibold,
                symbolScale: .large,
                paletteColors: [Colors.white, Colors.white, Colors.red]
            )
        rejectButton.setImage(rejectButtonImage, for: .normal)
        rejectButton.setImage(rejectButtonImage, for: .selected)
        rejectButton.setImage(rejectButtonImage, for: .highlighted)
        
        let endButtonImage = UIImage(systemName: "phone.down.circle.fill")?
            .applying(
                pointSize: 50.0,
                symbolWeight: .semibold,
                symbolScale: .large,
                paletteColors: [Colors.white, Colors.white, Colors.red]
            )
        endButton.setImage(endButtonImage, for: .normal)
        endButton.setImage(endButtonImage, for: .selected)
        endButton.setImage(endButtonImage, for: .highlighted)
             
        let cameraButtonImage = UIImage(resource: .threemaVideoCircle)
            .applying(
                pointSize: 40,
                symbolWeight: .thin,
                symbolScale: .large,
                paletteColors: [Colors.white, Colors.white, Colors.white]
            )
        cameraButton.setImage(cameraButtonImage, for: .normal)
        cameraButton.setImage(cameraButtonImage, for: .selected)
        cameraButton.setImage(cameraButtonImage, for: .highlighted)
        
        contactLabel.layer.shadowColor = UIColor.black.cgColor
        contactLabel.layer.shadowOffset = CGSize(width: 0, height: 0)
        contactLabel.layer.shadowRadius = 1.0
        contactLabel.layer.shadowOpacity = 0.2
        
        timerLabel.layer.shadowColor = UIColor.black.cgColor
        timerLabel.layer.shadowOffset = CGSize(width: 0, height: 0)
        timerLabel.layer.shadowRadius = 1.0
        timerLabel.layer.shadowOpacity = 0.2
        
        let cameraSwitchButtonImage = UIImage(resource: .threemaArrowTriangle2CirclepathCameraCircle)
            .applying(
                pointSize: 40.0,
                symbolWeight: .thin,
                symbolScale: .large,
                paletteColors: [Colors.white, Colors.white, Colors.white]
            )
        cameraSwitchButton.setImage(cameraSwitchButtonImage, for: .normal)
        cameraSwitchButton.setImage(cameraSwitchButtonImage, for: .selected)
        cameraSwitchButton.setImage(cameraSwitchButtonImage, for: .highlighted)
        
        let cellularWarningButtonImage = UIImage(resource: .threemaWifiExclamationmarkCircleFill)
            .applying(
                pointSize: 40.0,
                symbolWeight: .thin,
                symbolScale: .large,
                paletteColors: [Colors.red, Colors.white, Colors.white]
            )
        cellularWarningButton.setImage(cellularWarningButtonImage, for: .normal)
        cellularWarningButton.setImage(cellularWarningButtonImage, for: .selected)
        cellularWarningButton.setImage(cellularWarningButtonImage, for: .highlighted)
                
        let hideButtonImage = UIImage(systemName: "chevron.left")?
            .applying(
                pointSize: 28,
                symbolWeight: .semibold,
                symbolScale: .large,
                paletteColors: [Colors.white]
            )
        hideButton.imageView?.contentMode = .scaleAspectFit
        hideButton.setImage(hideButtonImage, for: .normal)
        hideButton.setImage(hideButtonImage, for: .selected)
        hideButton.setImage(hideButtonImage, for: .highlighted)
        hideButton.layer.cornerRadius = hideButton.frame.width / 2
        hideButton.layer.shadowColor = UIColor.black.cgColor
        hideButton.layer.shadowOffset = CGSize(width: 0, height: 0)
        hideButton.layer.shadowRadius = 1.0
        hideButton.layer.shadowOpacity = 0.2
        hideButton.layer.masksToBounds = false
                        
        if isTesting == true {
            setupForIncomCallTest()
        }
    }
    
    func setBackgroundForContact(contact: ContactEntity) {
        guard let avatarImage = AvatarMaker.shared().callBackground(for: contact) else {
            DDLogError("Could not create avatar image")
            return
        }
        if contact.isProfilePictureSet() {
            backgroundImage.image = blurImage(image: avatarImage, blurRadius: 4.0)
        }
        else {
            backgroundImage.image = avatarImage
        }
    }
    
    private func updateView() {
        if isTesting == false {
            DispatchQueue.main.async {
                if VoIPCallStateManager.shared.currentCallState() == .microphoneDisabled {
                    self.endButton?.isHidden = true
                    self.acceptButton?.isHidden = false
                    self.rejectButton?.isHidden = false
                    self.muteButton?.isHidden = true
                    self.phoneButtonsGradientView?.isHidden = true
                    self.speakerButton?.isHidden = true
                    self.cameraButton?.isHidden = true
                    self.cameraSwitchButton?.isHidden = true
                    self.localVideoView?.isHidden = true
                    self.remoteVideoView?.isHidden = true
                    
                    self.endButton?.isEnabled = false
                    self.acceptButton?.isEnabled = false
                    self.rejectButton?.isEnabled = false
                    self.muteButton?.isEnabled = false
                    self.speakerButton?.isEnabled = false
                    self.cameraButton?.isEnabled = false
                    self.cameraSwitchButton?.isEnabled = false
                    
                    self.voIPCallStatusChanged(state: .microphoneDisabled, oldState: .microphoneDisabled)
                }
                else {
                    self.endButton?.isHidden = !self.isCallInitiator && !self.alreadyAccepted
                    self.acceptButton?.isHidden = self.isCallInitiator || self.alreadyAccepted
                    self.rejectButton?.isHidden = self.isCallInitiator || self.alreadyAccepted
                    self.muteButton?.isHidden = !self.isCallInitiator && !self.alreadyAccepted
                    self.phoneButtonsGradientView?.isHidden = !self.isCallInitiator && !self.alreadyAccepted
                    self.phoneButtonsGradientView?.isHidden = !self.isCallInitiator && !self.alreadyAccepted
                    self.speakerButton?.isHidden = !self.isCallInitiator && !self.alreadyAccepted
                    
                    self.endButton?.isEnabled = true
                    self.acceptButton?.isEnabled = true
                    self.muteButton?.isEnabled = true
                    self.speakerButton?.isEnabled = true
                    
                    self.updateVideoViews()
                }
            }
        }
    }
    
    private func updateVideoViews() {
        if contact != nil, threemaVideoCallAvailable == true {
            let cameraButtonImage =
                UIImage(named: isLocalVideoActive ? "threema.video.circle.fill" : "threema.video.circle")?
                    .applying(
                        pointSize: 40,
                        symbolWeight: .thin,
                        symbolScale: .large,
                        paletteColors: [Colors.white, Colors.white, Colors.white]
                    )

            cameraButton?.setImage(cameraButtonImage, for: .normal)
            cameraButton?.setImage(cameraButtonImage, for: .selected)
            cameraButton?.setImage(cameraButtonImage, for: .highlighted)
            cameraButton?.accessibilityLabel = BundleUtil
                .localizedString(
                    forKey: isLocalVideoActive ? "call_camera_deactivate_button" :
                        "call_camera_activate_button"
                )
            cameraButton?.alpha = 1.0
            cameraButton?.isHidden = !isCallInitiator && !alreadyAccepted
            cameraSwitchButton?
                .isHidden =
                !(
                    isLocalVideoActive &&
                        (
                            AVCaptureDevice
                                .default(.builtInWideAngleCamera, for: AVMediaType.video, position: .back) != nil
                        )
                )
            cameraButton?.isEnabled = true
            cameraSwitchButton?.isEnabled = true
            
            localVideoView?.isHidden = !(isLocalVideoActive && isReceivingRemoteVideo)
            remoteVideoView?.isHidden = !(isLocalVideoActive || isReceivingRemoteVideo)
        }
        else {
            if alreadyAccepted, UserSettings.shared().enableVideoCall {
                let cameraButtonImage =
                    UIImage(named: isLocalVideoActive ? "threema.video.circle.fill" : "threema.video.circle")?
                        .applying(
                            pointSize: 40,
                            symbolWeight: .thin,
                            symbolScale: .large,
                            paletteColors: [Colors.gray, Colors.gray, Colors.gray]
                        )

                cameraButton?.setImage(cameraButtonImage, for: .normal)
                cameraButton?.setImage(cameraButtonImage, for: .selected)
                cameraButton?.setImage(cameraButtonImage, for: .highlighted)
                cameraButton?.accessibilityLabel = BundleUtil.localizedString(forKey: "call_camera_deactivate_button")
                cameraButton?.isHidden = isCallInitiator && !UserSettings.shared().enableVideoCall
                cameraButton?.alpha = 0.9
            }
            else {
                cameraButton?.alpha = 1.0
                cameraButton?.isHidden = true
            }
            
            localVideoView?.isHidden = true
            remoteVideoView?.isHidden = true
            cameraSwitchButton?.isHidden = true
            cameraButton?.isEnabled = true
            cameraSwitchButton?.isEnabled = false
        }
    }
    
    private func setupForIncomCallTest() {
        DispatchQueue.main.async {
            self.endButton.isHidden = true
            self.acceptButton.isHidden = false
            self.rejectButton.isHidden = false
            self.muteButton.isHidden = true
            self.speakerButton.isHidden = true
            self.timerLabel.isHidden = false
            self.cameraButton.isHidden = true
            self.cameraSwitchButton.isHidden = true
            self.debugLabel.isHidden = true
            self.cellularWarningButton.isHidden = true
        
            self.timerLabel.text = BundleUtil.localizedString(forKey: "call_status_incom_ringing")
        }
    }
    
    private func setupForConnectedCallTest() {
        debugLabel.isHidden = true
        endButton.isHidden = false
        acceptButton.isHidden = true
        rejectButton.isHidden = true
        muteButton.isHidden = false
        speakerButton.isHidden = false
        timerLabel.isHidden = false
        cameraButton.isHidden = false
        cameraSwitchButton.isHidden = true
        cellularWarningButton.isHidden = true
                
        endButton?.isEnabled = true
        muteButton?.isEnabled = true
        speakerButton?.isEnabled = true
        cameraButton?.isEnabled = true
        cameraSwitchButton.isEnabled = true
                
        DispatchQueue.main.async {
            self.timerLabel.text = "12:12"
        }
        
        let cameraButtonImage =
            UIImage(named: isLocalVideoActive ? "threema.video.circle.fill" : "threema.video.circle")?
                .applying(
                    pointSize: 40,
                    symbolWeight: .thin,
                    symbolScale: .large,
                    paletteColors: [Colors.white, Colors.white, Colors.white]
                )
        cameraButton?.setImage(cameraButtonImage, for: .normal)
        cameraButton?.setImage(cameraButtonImage, for: .selected)
        cameraButton?.setImage(cameraButtonImage, for: .highlighted)
    }
    
    private func setupForVideoCallTest() {
        debugLabel.isHidden = true
        endButton.isHidden = false
        acceptButton.isHidden = true
        rejectButton.isHidden = true
        muteButton.isHidden = false
        speakerButton.isHidden = false
        timerLabel.isHidden = false
        cameraButton.isHidden = false
        cameraButton.isSelected = true
        cameraSwitchButton.isHidden = false
        cellularWarningButton.isHidden = true
        
        endButton?.isEnabled = true
        muteButton?.isEnabled = true
        speakerButton?.isEnabled = true
        cameraButton?.isEnabled = true
        cameraSwitchButton.isEnabled = true
        
        let cameraButtonImage = UIImage(resource: .threemaVideoCircleFill)
            .applying(
                pointSize: 40,
                symbolWeight: .thin,
                symbolScale: .large,
                paletteColors: [Colors.white, Colors.white, Colors.white]
            )
        cameraButton?.setImage(cameraButtonImage, for: .normal)
        cameraButton?.setImage(cameraButtonImage, for: .selected)
        cameraButton?.setImage(cameraButtonImage, for: .highlighted)
        
        DispatchQueue.main.async {
            self.timerLabel.text = "12:12"
        }
        speakerButton.setImage(
            UIImage(systemName: "speaker.wave.2.circle.fill")?
                .applying(
                    pointSize: 36.0,
                    symbolWeight: .thin,
                    symbolScale: .large,
                    paletteColors: [Colors.black, Colors.black, Colors.white]
                ),
            for: .normal
        )
        
        localVideoView?.isHidden = false
        remoteVideoView?.isHidden = false
        
        var meImage = AvatarMaker.shared().unknownPersonImage()
        if let profilePicture = MyIdentityStore.shared()?.profilePicture {
            if let data = profilePicture["ProfilePicture"] {
                meImage = UIImage(data: data as! Data)
            }
        }
        
        let meImageView = UIImageView(image: meImage)
        meImageView.contentMode = .scaleAspectFill
        embedView(meImageView, into: localVideoView)
        
        let remoteImageView = UIImageView()
        if let contact {
            remoteImageView.image = AvatarMaker.shared()
                .avatar(for: contact, size: remoteVideoView.frame.size.width, masked: false)
        }
        remoteImageView.contentMode = .scaleAspectFill
        embedView(remoteImageView, into: remoteVideoView)
    }
    
    private func startLocalVideo(useBackCamera: Bool = false, switchCamera: Bool = false) {
        DispatchQueue.main.async {
            self.backgroundImage.image = nil
            #if arch(arm64)
                // Using metal (arm64 only)
                let localRenderer = RTCMTLVideoView(frame: self.localVideoView?.frame ?? CGRect.zero)
                localRenderer.videoContentMode = .scaleAspectFill
            #else
                // Using OpenGLES for the rest
                let localRenderer = RTCEAGLVideoView(frame: self.localVideoView?.frame ?? CGRect.zero)
            #endif
            localRenderer.delegate = self
            VoIPCallStateManager.shared.startCaptureLocalVideo(
                renderer: localRenderer,
                useBackCamera: useBackCamera,
                switchCamera: switchCamera
            )
            
            if !self.isReceivingRemoteVideo {
                if let remoteVideoView = self.remoteVideoView {
                    self.embedView(localRenderer, into: remoteVideoView)
                    self.flipLocalRenderer()
                    self.updateVideoViews()
                    if switchCamera == false {
                        self.activateSpeakerForVideo()
                    }
                }
            }
            else {
                if let localVideoView = self.localVideoView {
                    if self.isRemoteRendererInRemoteView() {
                        self.embedView(localRenderer, into: localVideoView)
                    }
                    else {
                        self.embedView(localRenderer, into: self.remoteVideoView)
                    }
                    
                    self.flipLocalRenderer()
                    self.updateVideoViews()
                    if switchCamera == false {
                        self.activateSpeakerForVideo()
                    }
                }
            }
        }
    }
    
    private func endLocalVideo(switchCamera: Bool = false) {
        VoIPCallStateManager.shared.endCaptureLocalVideo(switchCamera: switchCamera)
        
        DispatchQueue.main.async {
            if self.isReceivingRemoteVideo {
                if let remoteRenderer = VoIPCallStateManager.shared.remoteVideoRenderer() {
                    if self.localVideoView.subviews.first == remoteRenderer as? UIView {
                        if !switchCamera {
                            self.moveEmbedView(
                                remoteRenderer as! UIView,
                                from: self.localVideoView,
                                into: self.remoteVideoView
                            )
                        }
                        else {
                            self.removeSubviewsFromRemoteView()
                        }
                    }
                    else if self.remoteVideoView.subviews.first == remoteRenderer as? UIView {
                        self.removeSubviewsFromLocalView()
                    }
                }
            }
            else {
                if let contact = self.contact {
                    self.setBackgroundForContact(contact: contact)
                }
                self.removeAllSubviewsFromVideoViews()
            }
            self.flipLocalRenderer()
            self.updateVideoViews()
        }
    }

    private func startRemoteVideo() {
        func createNewRemoteVideoView() -> RTCMTLVideoView {
            let remoteRenderer = RTCMTLVideoView(frame: remoteVideoView?.frame ?? CGRect.zero)
            remoteRenderer.videoContentMode = .scaleAspectFill
            remoteRenderer.delegate = self
            VoIPCallStateManager.shared.renderRemoteVideo(to: remoteRenderer)
            return remoteRenderer
        }
        
        DispatchQueue.main.async {
            if self.viewIfLoaded?.window != nil {
                self.backgroundImage.image = nil
                let remoteRenderer = VoIPCallStateManager.shared
                    .remoteVideoRenderer() as? RTCMTLVideoView ?? createNewRemoteVideoView()
                
                if !self.isLocalVideoActive || self.localVideoView.subviews.first == VoIPCallStateManager.shared
                    .localVideoRenderer() as? UIView {
                    if let remoteVideoView = self.remoteVideoView,
                       remoteVideoView.subviews.first != remoteRenderer {
                        self.embedView(remoteRenderer, into: remoteVideoView)
                        self.updateVideoViews()
                    }
                }
                else {
                    if let localRenderer = VoIPCallStateManager.shared.localVideoRenderer() as? UIView,
                       let remoteVideoView = self.remoteVideoView,
                       localRenderer != self.localVideoView.subviews.first || remoteRenderer != remoteVideoView
                       .subviews.first,
                       remoteRenderer != self.localVideoView.subviews.first || localRenderer != remoteVideoView
                       .subviews.first {
                        self.moveEmbedView(
                            localRenderer,
                            from: self.remoteVideoView,
                            into: self.localVideoView
                        )
                        self.embedView(remoteRenderer, into: remoteVideoView)
                        self.flipLocalRenderer()
                        self.updateVideoViews()
                    }
                    else if let localRenderer = VoIPCallStateManager.shared.localVideoRenderer() as? UIView,
                            let remoteVideoView = self.remoteVideoView,
                            let localVideoView = self.localVideoView {
                        if localVideoView.subviews.first == localRenderer {
                            self.embedView(remoteRenderer, into: remoteVideoView)
                        }
                        else {
                            self.embedView(remoteRenderer, into: localVideoView)
                        }
                        self.updateVideoViews()
                    }
                }
            }
        }
    }
    
    private func endRemoteVideo() {
        VoIPCallStateManager.shared.endRemoteVideo()
        DispatchQueue.main.async {
            if self.viewIfLoaded?.window != nil {
                if self.isLocalVideoActive {
                    self.moveOrRemoveLocalRenderer()
                }
                else {
                    if let contact = self.contact {
                        self.setBackgroundForContact(contact: contact)
                    }
                    self.removeAllSubviewsFromVideoViews()
                }
                self.flipLocalRenderer()
                self.updateVideoViews()
            }
        }
    }
    
    private func moveOrRemoveLocalRenderer() {
        if let localRenderer = VoIPCallStateManager.shared.localVideoRenderer() {
            if localVideoView.subviews.first == localRenderer as? UIView {
                moveEmbedView(localRenderer as! UIView, from: localVideoView, into: remoteVideoView)
            }
            else if remoteVideoView.subviews.first == localRenderer as? UIView {
                removeSubviewsFromLocalView()
            }
        }
    }
    
    private func embedView(_ view: UIView, into containerView: UIView) {
        containerView.subviews.forEach { $0.removeFromSuperview() }
        containerView.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.masksToBounds = true

        containerView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        containerView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        containerView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        
        containerView.layoutIfNeeded()
    }
    
    private func moveEmbedView(_ view: UIView, from fromContainerView: UIView, into containerView: UIView) {
        removeAllSubviewsFromVideoViews()
        embedView(view, into: containerView)
    }
    
    private func switchCamera() {
        useBackCamera = !useBackCamera
        cameraSwitchButton.accessibilityLabel = BundleUtil
            .localizedString(
                forKey: useBackCamera ? "call_camera_switch_to_front_button" :
                    "call_camera_switch_to_back_button"
            )
        endLocalVideo(switchCamera: true)
        startLocalVideo(useBackCamera: useBackCamera, switchCamera: true)
    }
    
    private func isLocalRendererInLocalView() -> Bool {
        if let localRenderer = VoIPCallStateManager.shared.localVideoRenderer() as? UIView {
            if localVideoView.subviews.first == localRenderer {
                return true
            }
        }
        return false
    }
    
    private func isLocalRendererInRemoteView() -> Bool {
        if let localRenderer = VoIPCallStateManager.shared.localVideoRenderer() as? UIView {
            if remoteVideoView.subviews.first == localRenderer {
                return true
            }
        }
        return false
    }
    
    private func isRemoteRendererInRemoteView() -> Bool {
        if let remoteRenderer = VoIPCallStateManager.shared.remoteVideoRenderer() as? UIView {
            if remoteVideoView.subviews.first == remoteRenderer {
                return true
            }
        }
        return false
    }
    
    private func isRemoteRendererInLocalView() -> Bool {
        if let remoteRenderer = VoIPCallStateManager.shared.remoteVideoRenderer() as? UIView {
            if localVideoView.subviews.first == remoteRenderer {
                return true
            }
        }
        return false
    }
    
    private func removeSubviewsFromLocalView() {
        guard localVideoView != nil else {
            return
        }
        guard !localVideoView.subviews.isEmpty else {
            return
        }
        localVideoView.subviews.forEach { $0.removeFromSuperview() }
    }
    
    private func removeSubviewsFromRemoteView() {
        guard remoteVideoView != nil else {
            return
        }
        guard !remoteVideoView.subviews.isEmpty else {
            return
        }
        remoteVideoView.subviews.forEach { $0.removeFromSuperview() }
    }
    
    private func removeAllSubviewsFromVideoViews() {
        removeSubviewsFromLocalView()
        removeSubviewsFromRemoteView()
        
        // show navigation if needed
        if !isNavigationVisible() {
            moveLocalVideoViewToCorrectPosition(moveNavigation: true)
        }
    }
    
    private func flipLocalRenderer() {
        if useBackCamera == false {
            if isLocalRendererInLocalView() {
                if localVideoView != nil {
                    localVideoView.layer.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1))
                }
            }
            else {
                if localVideoView != nil {
                    localVideoView.layer.setAffineTransform(CGAffineTransform(scaleX: 1, y: 1))
                }
            }
            
            if isLocalRendererInRemoteView() {
                if remoteVideoView != nil {
                    remoteVideoView.layer.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1))
                }
            }
            else {
                if remoteVideoView != nil {
                    remoteVideoView.layer.setAffineTransform(CGAffineTransform(scaleX: 1, y: 1))
                }
            }
        }
        else {
            if localVideoView != nil {
                localVideoView.layer.setAffineTransform(CGAffineTransform(scaleX: 1, y: 1))
            }
            if remoteVideoView != nil {
                remoteVideoView.layer.setAffineTransform(CGAffineTransform(scaleX: 1, y: 1))
            }
        }
    }
    
    private func hasCameraAccess() -> Bool {
        let access = AVCaptureDevice.authorizationStatus(for: .video)
        if access == .authorized {
            return true
        }
        else if access == .denied || access == .restricted {
            showCameraAccessAlert()
        }
        else if access == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) in
                if granted {
                    self.isLocalVideoActive = !self.isLocalVideoActive
                    if self.isLocalVideoActive == true {
                        self.startLocalVideo()
                    }
                    else {
                        self.endLocalVideo()
                    }
                }
                else {
                    self.showCameraAccessAlert()
                }
            })
        }
        return false
    }

    private func showCameraAccessAlert() {
        // Show access prompt
        DispatchQueue.main.async {
            UIAlertTemplate.showOpenSettingsAlert(
                owner: self,
                noAccessAlertType: .camera
            )
        }
    }
    
    private func activateSpeakerForVideo() {
        let currentRoute = AVAudioSession.sharedInstance().currentRoute
        
        for output in currentRoute.outputs {
            if output.portType == AVAudioSession.Port.builtInReceiver {
                let action = VoIPCallUserAction(
                    action: .speakerOn,
                    contactIdentity: contactIdentity!,
                    callID: VoIPCallStateManager.shared.currentCallID(),
                    completion: nil
                )
                VoIPCallStateManager.shared.processUserAction(action)
            }
        }
    }
    
    private func isNavigationVisible() -> Bool {
        guard let navigationConstraint = phoneButtonsStackViewBottomConstraint else {
            return true
        }
        return navigationConstraint.constant == 0.0
    }
    
    private func removeAllLocalVideoViewConstraints() {
        localVideoViewConstraintLeft.isActive = false
        localVideoViewConstraintRight.isActive = false
        localVideoViewConstraintBottom.isActive = false
        localVideoViewConstraintBottomNavigation.isActive = false
        localVideoViewConstraintTop.isActive = false
        localVideoViewConstraintTopNavigation.isActive = false
        localVideoViewConstraintTopNavigationLabel.isActive = false
        view.layoutIfNeeded()
    }
    
    private func moveLocalVideoViewToCorrectPosition(moveNavigation: Bool = false) {
        let localVideoViewCenterX = localVideoView.center.x
        let localVideoViewCenterY = localVideoView.center.y
        let screenMiddleX = view.frame.size.width / 2
        let screenMiddleY = view.frame.size.height / 2
        
        removeAllLocalVideoViewConstraints()
                
        guard let _ = phoneButtonsStackViewBottomConstraint,
              let _ = callInfoStackViewTopConstraint,
              let _ = phoneButtonsStackView,
              let _ = callInfoStackView,
              let phoneButtonsStackViewSuperView = phoneButtonsStackView.superview,
              let callInfoStackViewSuperView = callInfoStackView.superview else {
            return
        }
        
        if moveNavigation {
            if isNavigationVisible() {
                phoneButtonsStackViewBottomConstraint.constant = phoneButtonsStackView.frame.size
                    .height + phoneButtonsStackViewSuperView.layoutMargins.bottom + 50.0
                callInfoStackViewTopConstraint
                    .constant = -(
                        callInfoStackView.frame.size.height + callInfoStackViewSuperView
                            .layoutMargins.top + 50.0
                    )
            }
            else {
                phoneButtonsStackViewBottomConstraint.constant = 0
                callInfoStackViewTopConstraint.constant = 16.0
            }
        }
        
        if localVideoViewCenterX < screenMiddleX, localVideoViewCenterY < screenMiddleY {
            addConstraintToTopLeftForLocalVideoView()
        }
        else if localVideoViewCenterX > screenMiddleX, localVideoViewCenterY < screenMiddleY {
            addConstraintToTopRightForLocalVideoView()
        }
        else if localVideoViewCenterX < screenMiddleX, localVideoViewCenterY > screenMiddleY {
            addConstraintToBottomLeftForLocalVideoView()
        }
        else if localVideoViewCenterX > screenMiddleX, localVideoViewCenterY > screenMiddleY {
            addConstraintToBottomRightForLocalVideoView()
        }
        
        UIView.animate(withDuration: 0.35, animations: {
            self.phoneButtonsGradientView.setNeedsLayout()
            self.phoneButtonsGradientView.layoutIfNeeded()
            self.callInfoGradientView.setNeedsLayout()
            self.callInfoGradientView.layoutIfNeeded()
            self.view.layoutIfNeeded()
        })
    }
    
    private func addConstraintToTopLeftForLocalVideoView() {
        localVideoViewConstraintLeft.isActive = true
        
        if isNavigationVisible() {
            localVideoViewConstraintTopNavigationLabel.isActive = true
        }
        else {
            localVideoViewConstraintTop.isActive = true
        }
    }
    
    private func addConstraintToTopRightForLocalVideoView() {
        localVideoViewConstraintRight.isActive = true
        if isNavigationVisible() {
            localVideoViewConstraintTopNavigation.isActive = true
        }
        else {
            localVideoViewConstraintTop.isActive = true
        }
    }
    
    private func addConstraintToBottomLeftForLocalVideoView() {
        localVideoViewConstraintLeft.isActive = true
        if isNavigationVisible() {
            localVideoViewConstraintBottomNavigation.isActive = true
        }
        else {
            localVideoViewConstraintBottom.isActive = true
        }
    }
    
    private func addConstraintToBottomRightForLocalVideoView() {
        localVideoViewConstraintRight.isActive = true
        if isNavigationVisible() {
            localVideoViewConstraintBottomNavigation.isActive = true
        }
        else {
            localVideoViewConstraintBottom.isActive = true
        }
    }
    
    private func updateConstraintsAfterRotation(size: CGSize?) {
        if isLocalRendererInLocalView() || isRemoteRendererInLocalView() {
            var maxSize: CGFloat = 100
            var newSize = size ?? CGSize(width: maxSize, height: 134.0)
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                maxSize = 200
                newSize = size ?? CGSize(width: maxSize, height: 268.0)
            }
            
            if UIDevice.current.orientation == .landscapeLeft || UIDevice.current.orientation == .landscapeRight {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    maxSize = 270.0
                }
                else {
                    maxSize = 150.0
                }
            }
            
            let ratio = newSize.width / maxSize
            localVideoViewConstraintHeight.constant = newSize.height / ratio
            localVideoViewConstraintWidth.constant = newSize.width / ratio
            
            view.layoutIfNeeded()
        }
    }
    
    private func checkAndHandleAvailableBluetoothDevices() {
        var bluetoothAvailable = false
        if let inputs = AVAudioSession.sharedInstance().availableInputs {
            for input in inputs {
                if input.portType == AVAudioSession.Port.bluetoothA2DP || input.portType == AVAudioSession.Port
                    .bluetoothHFP || input.portType == AVAudioSession.Port.bluetoothLE {
                    bluetoothAvailable = true
                }
            }
        }
        
        if bluetoothAvailable {
            if myVolumeView == nil {
                myVolumeView =
                    AVRoutePickerView(frame: CGRect(
                        x: 0.0,
                        y: 0.0,
                        width: speakerButton.frame.size.width,
                        height: speakerButton.frame.size.height
                    ))
                (myVolumeView as! AVRoutePickerView).activeTintColor = UIColor.clear
                (myVolumeView as! AVRoutePickerView).tintColor = UIColor.clear
                (myVolumeView as! AVRoutePickerView).isOpaque = true
                (myVolumeView as! AVRoutePickerView).alpha = 1.0
                (myVolumeView as! AVRoutePickerView).delegate = self
                if isLocalVideoActive || isReceivingRemoteVideo {
                    (myVolumeView as! AVRoutePickerView).prioritizesVideoDevices = true
                }
                speakerButton.addSubview(myVolumeView!)
            }
        }
        else {
            for subview in speakerButton.subviews {
                if subview == myVolumeView {
                    subview.removeFromSuperview()
                }
            }
            myVolumeView = nil
        }
    }
    
    private func blurImage(image: UIImage, blurRadius: CGFloat) -> UIImage {
        let context = CIContext(options: nil)
        let inputImage = CIImage(cgImage: image.cgImage!)

        let blurFilter = CIFilter(name: "CIGaussianBlur")
        blurFilter?.setValue(inputImage, forKey: kCIInputImageKey)
        blurFilter?.setValue(blurRadius, forKey: "inputRadius")
        
        var bounds = inputImage.extent
        if AvatarMaker.shared().isDefaultAvatar(for: contact) {
            bounds = CGRect(x: -10.0, y: -10.0, width: image.size.width + 20.0, height: image.size.height + 20.0)
        }
        else {
            bounds = CGRect(
                x: bounds.origin.x + 10.0,
                y: bounds.origin.y + 10.0,
                width: bounds.size.width - 20.0,
                height: bounds.size.height - 20.0
            )
        }
        
        let outputImage = blurFilter?.value(forKey: kCIOutputImageKey) as? CIImage
        let cgImage = context.createCGImage(outputImage ?? CIImage(), from: bounds)
        return UIImage(cgImage: cgImage!)
    }
    
    private func addGradientToView(
        view: UIView,
        startColor: UIColor,
        middleColor: UIColor,
        endColor: UIColor,
        locations: [NSNumber]
    ) {
        let gradientLayerMask = CAGradientLayer()
        gradientLayerMask.colors = [startColor.cgColor, middleColor.cgColor, endColor.cgColor]
        gradientLayerMask.locations = locations
        gradientLayerMask.frame = view.bounds
        view.layer.insertSublayer(gradientLayerMask, at: 0)
        view.backgroundColor = .clear
    }
    
    private func updateGradientBackground() {
        
        callInfoGradientView.setNeedsLayout()
        callInfoGradientView.layoutIfNeeded()
        phoneButtonsGradientView.setNeedsLayout()
        phoneButtonsGradientView.layoutIfNeeded()
        
        callInfoGradientView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        phoneButtonsGradientView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        addGradientToView(
            view: callInfoGradientView,
            startColor: UIColor.black.withAlphaComponent(0.2),
            middleColor: UIColor.black.withAlphaComponent(0.1),
            endColor: UIColor.white.withAlphaComponent(0.0),
            locations: [0, 0.7, 1]
        )
        addGradientToView(
            view: phoneButtonsGradientView,
            startColor: UIColor.white.withAlphaComponent(0.0),
            middleColor: UIColor.black.withAlphaComponent(0.1),
            endColor: UIColor.black.withAlphaComponent(0.2),
            locations: [0, 0.3, 1]
        )
    }
    
    private func updateRemoteVideoContentMode(videoView: RTCVideoRenderer) {
        #if arch(arm64)
            if let rR = VoIPCallStateManager.shared.remoteVideoRenderer(),
               let remoteRenderer = rR as? RTCMTLVideoView,
               remoteRenderer.isEqual(videoView) {
                if UIApplication.shared.statusBarOrientation.isPortrait,
                   isRemoteVideoPortrait {
                    remoteRenderer.videoContentMode = .scaleAspectFill
                }
                else {
                    if UIApplication.shared.statusBarOrientation.isLandscape,
                       !isRemoteVideoPortrait {
                        remoteRenderer.videoContentMode = .scaleAspectFill
                    }
                    else {
                        remoteRenderer.videoContentMode = .scaleAspectFit
                    }
                }
            }
        #endif
    }
    
    private func updateAccessibilityLabels() {
        muteButton.accessibilityLabel = BundleUtil
            .localizedString(forKey: muteButton.isSelected ? "call_unmute" : "call_mute")
        speakerButton.accessibilityLabel = BundleUtil
            .localizedString(forKey: speakerButton.tag == 1 ? "call_earpiece" : "call_speaker")
        endButton.accessibilityLabel = BundleUtil.localizedString(forKey: "call_end")
        acceptButton.accessibilityLabel = BundleUtil.localizedString(forKey: "call_accept")
        rejectButton.accessibilityLabel = BundleUtil.localizedString(forKey: "call_reject")
        hideButton.accessibilityLabel = BundleUtil.localizedString(forKey: "call_hide_call")
        
        cameraButton.accessibilityLabel = BundleUtil
            .localizedString(
                forKey: isLocalVideoActive ? "call_camera_deactivate_button" :
                    "call_camera_activate_button"
            )
        cameraSwitchButton.accessibilityLabel = BundleUtil.localizedString(forKey: "call_camera_switch_to_back_button")
    }
    
    /// It will play the problem sound
    private func playCellularCallWarningSound() {
        audioPlayer?.stop()
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.duckOthers, .allowBluetooth, .allowBluetoothA2DP]
            )
            try audioSession.overrideOutputAudioPort(VoIPCallStateManager.shared.isSpeakerActive() ? .speaker : .none)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            let soundFilePath = BundleUtil.path(forResource: "threema_problem", ofType: "mp3")
            let soundURL = URL(fileURLWithPath: soundFilePath!)
            let player = try AVAudioPlayer(contentsOf: soundURL, fileTypeHint: AVFileType.mp3.rawValue)
            player.numberOfLoops = 2
            audioPlayer = player
            player.play()
        }
        catch {
            print(error.localizedDescription)
        }
    }
}

extension CallViewController {
    // MARK: Actions
    
    @objc private func handleLongPress(gestureRecognizer: UIGestureRecognizer) {
        if gestureRecognizer.state == .began {
            // Toggle debug label
            debugLabel.isHidden = !debugLabel.isHidden
            
            if debugLabel.isHidden == true {
                debugLabel.text = ""
            }
        }
        
        updateViewConstraints()
    }
    
    @IBAction func hideView(sender: UIButton) {
        if isTesting == true {
            setupForConnectedCallTest()
        }
        else {
            NavigationBarPromptHandler.isCallActiveInBackground = true
            NavigationBarPromptHandler.name = contact?.displayName
            UIDevice.current.isProximityMonitoringEnabled = false
            
            NotificationCenter.default.post(
                name: NSNotification.Name(rawValue: kNotificationNavigationItemPromptShouldChange),
                object: nil
            )
            
            dismiss(animated: true) {
                if AppDelegate.shared()?.isAppLocked == true {
                    AppDelegate.shared()?.presentPasscodeView()
                }
            }
        }
    }
    
    @IBAction func acceptAction(_ sender: UIButton, forEvent event: UIEvent) {
        let action = VoIPCallUserAction(
            action: .accept,
            contactIdentity: contactIdentity!,
            callID: VoIPCallStateManager.shared.currentCallID(),
            completion: nil
        )
        VoIPCallStateManager.shared.processUserAction(action)
    }
    
    @IBAction func rejectAction(_ sender: UIButton, forEvent event: UIEvent) {
        if isTesting == true {
            dismiss(animated: true, completion: nil)
        }
        else {
            let action = VoIPCallUserAction(
                action: .reject,
                contactIdentity: contactIdentity!,
                callID: VoIPCallStateManager.shared.currentCallID(),
                completion: nil
            )
            VoIPCallStateManager.shared.processUserAction(action)
        }
    }
    
    @IBAction func endAction(_ sender: UIButton, forEvent event: UIEvent) {
        DDLogNotice(
            "VoipCallService: [cid=\(VoIPCallStateManager.shared.currentCallID()?.callID ?? 0)]: User pressed the hangup button"
        )

        let action = VoIPCallUserAction(
            action: .end,
            contactIdentity: contactIdentity!,
            callID: VoIPCallStateManager.shared.currentCallID(),
            completion: nil
        )
        VoIPCallStateManager.shared.processUserAction(action)
    }
    
    @IBAction func muteAction(_ sender: UIButton, forEvent event: UIEvent) {
        let action = VoIPCallUserAction(
            action: VoIPCallStateManager.shared.isCallMuted() ? .unmuteAudio : .muteAudio,
            contactIdentity: contactIdentity!,
            callID: VoIPCallStateManager.shared.currentCallID(),
            completion: nil
        )
        muteButton.isSelected = action.action == .muteAudio
        updateAccessibilityLabels()
        VoIPCallStateManager.shared.processUserAction(action)
    }
    
    @IBAction func speakerAction(_ sender: UIButton, forEvent event: UIEvent) {
        checkAndHandleAvailableBluetoothDevices()
        
        let audioSession = AVAudioSession.sharedInstance()
        for output in audioSession.currentRoute.outputs {
            switch output.portType {
            case .builtInReceiver:
                let action = VoIPCallUserAction(
                    action: .speakerOn,
                    contactIdentity: contactIdentity!,
                    callID: VoIPCallStateManager.shared.currentCallID(),
                    completion: nil
                )
                VoIPCallStateManager.shared.processUserAction(action)
            case .builtInSpeaker:
                let action = VoIPCallUserAction(
                    action: .speakerOff,
                    contactIdentity: contactIdentity!,
                    callID: VoIPCallStateManager.shared.currentCallID(),
                    completion: nil
                )
                VoIPCallStateManager.shared.processUserAction(action)
            case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
                let action = VoIPCallUserAction(
                    action: .speakerOn,
                    contactIdentity: contactIdentity!,
                    callID: VoIPCallStateManager.shared.currentCallID(),
                    completion: nil
                )
                VoIPCallStateManager.shared.processUserAction(action)
            case .headphones:
                let action = VoIPCallUserAction(
                    action: .speakerOn,
                    contactIdentity: contactIdentity!,
                    callID: VoIPCallStateManager.shared.currentCallID(),
                    completion: nil
                )
                VoIPCallStateManager.shared.processUserAction(action)
            default:
                break
            }
        }
        updateAccessibilityLabels()
    }
    
    @IBAction func startVideoAction(_ sender: UIButton) {
        if isTesting == true {
            setupForVideoCallTest()
        }
        else {
            if threemaVideoCallAvailable, hasCameraAccess() {
                isLocalVideoActive = !isLocalVideoActive
                if isLocalVideoActive == true {
                    startLocalVideo()
                }
                else {
                    endLocalVideo()
                }
            }
        }
    }
    
    @IBAction func switchCameraAction(_ sender: UIButton, forEvent event: UIEvent) {
        switchCamera()
    }
    
    @IBAction func showCellularWarningAction() {
        UIAlertTemplate.showAlert(
            owner: self,
            title: BundleUtil.localizedString(forKey: "call_threema_cellular_instead_of_wifi_title"),
            message: BundleUtil.localizedString(forKey: "call_threema_cellular_instead_of_wifi_text")
        )
    }
        
    @objc func switchVideoViews(gesture: UITapGestureRecognizer) {
        DispatchQueue.main.async {
            if self.isLocalRendererInLocalView(), self.isRemoteRendererInRemoteView() {
                self.removeAllSubviewsFromVideoViews()
                self.embedView(VoIPCallStateManager.shared.remoteVideoRenderer()! as! UIView, into: self.localVideoView)
                self.embedView(VoIPCallStateManager.shared.localVideoRenderer() as! UIView, into: self.remoteVideoView)
                self.flipLocalRenderer()
            }
            else if self.isLocalRendererInRemoteView(), self.isRemoteRendererInLocalView() {
                self.removeAllSubviewsFromVideoViews()
                self.embedView(VoIPCallStateManager.shared.localVideoRenderer()! as! UIView, into: self.localVideoView)
                self.embedView(VoIPCallStateManager.shared.remoteVideoRenderer() as! UIView, into: self.remoteVideoView)
                self.flipLocalRenderer()
            }
        }
    }
        
    @objc func showHideNavigation(gesture: UITapGestureRecognizer) {
        moveLocalVideoViewToCorrectPosition(moveNavigation: true)
    }
        
    @objc func didPan(gesture: UIPanGestureRecognizer) {
        guard let dragView = gesture.view else {
            return
        }
        
        if gesture.state == .began {
            dragView.center = gesture.location(in: view)
        }
        
        let newCenter: CGPoint = gesture.location(in: view)
        let dX = newCenter.x - dragView.center.x
        let dY = newCenter.y - dragView.center.y
        dragView.center = CGPoint(x: dragView.center.x + dX, y: dragView.center.y + dY)
        localVideoView.center = dragView.center

        if gesture.state == .ended {
            moveLocalVideoViewToCorrectPosition()
        }
    }
}

// MARK: - AVRoutePickerViewDelegate

extension CallViewController: AVRoutePickerViewDelegate {
    func routePickerViewDidEndPresentingRoutes(_ routePickerView: AVRoutePickerView) {
        checkAndHandleAvailableBluetoothDevices()
    }
}

// MARK: - RTCVideoViewDelegate

extension CallViewController: RTCVideoViewDelegate {
    func videoView(_ videoView: RTCVideoRenderer, didChangeVideoSize size: CGSize) {
        isRemoteVideoPortrait = size.height > size.width
        updateRemoteVideoContentMode(videoView: videoView)

        if let localRenderer = VoIPCallStateManager.shared.localVideoRenderer(),
           localRenderer.isEqual(videoView) {
            updateConstraintsAfterRotation(size: size)
        }
    }
}
