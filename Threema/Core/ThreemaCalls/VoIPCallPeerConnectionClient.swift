//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2025 Threema GmbH
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

// swiftformat:disable acronyms

import AVFoundation
import CocoaLumberjackSwift
import Foundation
import Reachability
import ThreemaFramework
import WebRTC

protocol VoIPCallPeerConnectionClientDelegate: AnyObject {
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClientProtocol, changeState: VoIPCallService.CallState)
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClientProtocol, audioMuted: Bool)
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClientProtocol, speakerActive: Bool)
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClientProtocol, removedCandidates: [RTCIceCandidate])
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClientProtocol, addedCandidate: RTCIceCandidate)
    func peerConnectionClient(
        _ client: VoIPCallPeerConnectionClientProtocol,
        didChangeConnectionState state: RTCPeerConnectionState
    )
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClientProtocol, receivingVideo: Bool)
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClientProtocol, didReceiveData: Data)
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClientProtocol, shouldShowCellularCallWarning: Bool)
    func peerconnectionClient(_ client: VoIPCallPeerConnectionClientProtocol, startTransportExpectedStableTimer: Bool)
}

protocol VoIPCallPeerConnectionClientProtocol {
    var delegate: VoIPCallPeerConnectionClientDelegate? { get set }
    var peerConnection: RTCPeerConnection? { get }
    var remoteVideoQualityProfile: CallsignalingProtocol.ThreemaVideoCallQualityProfile? { get set }
    var isRemoteVideoActivated: Bool { get set }
    var networkIsRelayed: Bool { get }

    func initialize(
        contactIdentity: String,
        callID: VoIPCallID?,
        peerConnectionParameters: PeerConnectionParameters,
        delegate: VoIPCallPeerConnectionClientDelegate,
        completion: @escaping (Error?) -> Void
    )
    func close()

    func muteAudio(completion: @escaping () -> Void)
    func unmuteAudio(completion: @escaping () -> Void)
    func activateRTCAudio(speakerActive: Bool)
    func speakerOff()
    func speakerOn()

    func startCaptureLocalVideo(renderer: RTCVideoRenderer, useBackCamera: Bool, switchCamera: Bool)
    func endCaptureLocalVideo(renderer: RTCVideoRenderer, switchCamera: Bool)
    func renderRemoteVideo(to renderer: RTCVideoRenderer)
    func endRemoteVideo(renderer: RTCVideoRenderer)
    func stopVideoCall()

    func offer(completion: @escaping (_ sdp: RTCSessionDescription?, _ error: VoIPCallSdpPatcher.SdpError?) -> Void)
    func answer(completion: @escaping (_ sdp: RTCSessionDescription) -> Void)
    func set(remoteSdp: RTCSessionDescription, completion: @escaping (Error?) -> Void)
    func set(addRemoteCandidate: RTCIceCandidate)

    func logDebugEndStats(completion: @escaping () -> Void)
}

struct PeerConnectionParameters {
    public var isVideoCallAvailable = true
    public var videoCodecHwAcceleration = true
    public var forceTurn = false
    public var gatherContinually = false
    public var allowIpv6 = true

    var isDataChannelAvailable = false
}

final class VoIPCallPeerConnectionClient: NSObject, VoIPCallPeerConnectionClientProtocol {
    
    // The `RTCPeerConnectionFactory` is in charge of creating new RTCPeerConnection instances.
    // A new RTCPeerConnection should be created every new call, but the factory is shared.
    private static var factory: RTCPeerConnectionFactory = {
        let fieldtrials = [kRTCFieldTrialUseNWPathMonitor: kRTCFieldTrialEnabledValue]
        RTCInitFieldTrialDictionary(fieldtrials)

        let decoderFactory = RTCDefaultVideoDecoderFactory()
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        return RTCPeerConnectionFactory(encoderFactory: encoderFactory, decoderFactory: decoderFactory)
    }()
        
    weak var delegate: VoIPCallPeerConnectionClientDelegate?

    var remoteVideoQualityProfile: CallsignalingProtocol.ThreemaVideoCallQualityProfile? {
        didSet {
            let newProfile = CallsignalingProtocol.findCommonProfile(
                remoteProfile: remoteVideoQualityProfile,
                networkIsRelayed: networkIsRelayed
            )
            setOutgoingVideoLimits(
                maxBitrate: Int(newProfile.bitrate) * 1000,
                maxFps: Int(newProfile.maxFps),
                w: UInt32(newProfile.maxResolution.width),
                h: UInt32(newProfile.maxResolution.height)
            )
        }
    }

    var isRemoteVideoActivated = false {
        didSet {
            delegate?.peerConnectionClient(self, receivingVideo: true)
        }
    }
    
    var peerConnection: RTCPeerConnection?
    private var peerConnectionParameters: PeerConnectionParameters?

    private let rtcAudioSession = RTCAudioSession.sharedInstance()
    private let audioQueue = DispatchQueue(label: "VoIPCallAudioQueue")
    
    private var dataChannelQueue = Queue<Any>()
    private let dataChannelLockQueue = DispatchQueue(label: "VoIIPCallPeerConnectionClientLockQueue")
    
    private var videoCapturer: RTCVideoCapturer?
    private var localVideoTrack: RTCVideoTrack?
    private var localVideoSender: RTCRtpSender?
    private var remoteVideoTrack: RTCVideoTrack?
    private var dataChannel: RTCDataChannel?
        
    private var statsTimer: Timer?
    private var receivingVideoTimer: Timer?
    
    private var contactIdentity: String?
    
    private let internetReachability = try! Reachability()
    private var lastInternetStatus: Reachability.Connection?
    private(set) var networkIsRelayed = false // will be checked every 30 seconds after connection is established
    
    private var previousPeriodDebugState: VoIPStatsState?
    private var previousVideoState: VoIPStatsState?
    
    private var callID: VoIPCallID?
    
    private var isSelectedCandidatePairCellular = false {
        didSet {
            let shouldShowCellularCallWarning = isSelectedCandidatePairCellular && lastInternetStatus ==
                .wifi
            delegate?.peerConnectionClient(self, shouldShowCellularCallWarning: shouldShowCellularCallWarning)
        }
    }
    
    private static let logStatsIntervalConnecting = 2.0
    private static let logStatsIntervalConnected = 30.0
    private static let checkReceivingVideoInterval = 2.0
    
    private var videoCallQualityObserver: NSObjectProtocol?
    
    private let webrtcLogger = RTCCallbackLogger()

    enum VoIPCallPeerConnectionClientError: Error {
        case peerConnectionIsNotInitialized
    }
    
    override init() {
        webrtcLogger.severity = .warning
        webrtcLogger.start { message in
            let trimmed = message.trimmingCharacters(in: .newlines)
            DDLogNotice("libwebrtc: \(trimmed)")
        }
        super.init()
    }
    
    deinit {
        internetReachability.stopNotifier()
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.reachabilityChanged, object: nil)
        if let observer = videoCallQualityObserver {
            videoCallQualityObserver = nil
            NotificationCenter.default.removeObserver(observer)
        }
        webrtcLogger.stop()
    }

    /// Init new peer connection with a contact
    /// - parameter contact: Call contact
    func initialize(
        contactIdentity: String,
        callID: VoIPCallID?,
        peerConnectionParameters: PeerConnectionParameters,
        delegate: VoIPCallPeerConnectionClientDelegate,
        completion: @escaping (Error?) -> Void
    ) {
        self.peerConnectionParameters = peerConnectionParameters
        self.delegate = delegate

        VoIPCallPeerConnectionClient
            .defaultRTCConfiguration(peerConnectionParameters: peerConnectionParameters) { result in
                do {
                    let constraints = VoIPCallPeerConnectionClient.defaultPeerConnectionConstraints()
                    self.peerConnection = try VoIPCallPeerConnectionClient.factory.peerConnection(
                        with: result.get(),
                        constraints: constraints,
                        delegate: nil
                    )!
                    self.contactIdentity = contactIdentity
                    self.callID = callID

                    self.createMediaSenders()
                    self.configureAudioSession()
                    self.peerConnection?.delegate = self
                    NotificationCenter.default.addObserver(
                        self,
                        selector: #selector(self.networkStatusDidChange),
                        name: NSNotification.Name.reachabilityChanged,
                        object: nil
                    )
                    self.videoCallQualityObserver = NotificationCenter.default.addObserver(
                        forName: Notification.Name(kThreemaVideoCallsQualitySettingChanged),
                        object: nil,
                        queue: nil
                    ) { [weak self] _ in
                        guard let self else {
                            return
                        }
                        setQualityProfileForVideoSource()
                    }
                    if let protobufMessage = CallsignalingProtocol
                        .encodeVideoQuality(CallsignalingProtocol.localPeerQualityProfile().profile!) {
                        self.sendDataToRemote(protobufMessage)
                    }
                    try self.internetReachability.startNotifier()
                    self.lastInternetStatus = self.internetReachability.connection

                    completion(nil)
                }
                catch {
                    completion(error)
                }
            }
    }

    func close() {
        peerConnection?.close()
        peerConnection = nil
        
        do {
            RTCAudioSession.sharedInstance().lockForConfiguration()
            try RTCAudioSession.sharedInstance().setActive(false)
            RTCAudioSession.sharedInstance().unlockForConfiguration()
        }
        catch {
            DDLogError("Could not set shared session to not active. Error: \(error)")
        }
    }
}

extension VoIPCallPeerConnectionClient {
    // MARK: - Audio control
    
    /// Mute the audio of the rtc session
    func muteAudio(completion: @escaping () -> Void) {
        setAudioEnabled(false)
        delegate?.peerConnectionClient(self, audioMuted: true)
        if let protobufMessage = CallsignalingProtocol.encodeMute(true) {
            sendDataToRemote(protobufMessage)
        }
        completion()
    }
    
    /// Unmute the audio of the rtc session
    func unmuteAudio(completion: @escaping () -> Void) {
        setAudioEnabled(true)
        delegate?.peerConnectionClient(self, audioMuted: false)
        if let protobufMessage = CallsignalingProtocol.encodeMute(false) {
            sendDataToRemote(protobufMessage)
        }
        completion()
    }
    
    /// Activate RTC audio
    func activateRTCAudio(speakerActive: Bool) {
        audioQueue.async { [weak self] in
            guard let self else {
                return
            }
            rtcAudioSession.lockForConfiguration()
            do {
                try rtcAudioSession.setCategory(
                    AVAudioSession.Category.playAndRecord,
                    with: [.duckOthers, .allowBluetooth, .allowBluetoothA2DP]
                )
                try rtcAudioSession.setMode(.voiceChat)
                try rtcAudioSession.overrideOutputAudioPort(speakerActive ? .speaker : .none)
                try rtcAudioSession.setActive(true)
            }
            catch {
                debugPrint("Error setting AVAudioSession category: \(error)")
            }
            rtcAudioSession.unlockForConfiguration()
                        
            rtcAudioSession.isAudioEnabled = true
        }
    }
    
    /// Disable the speaker for the rtc session
    func speakerOff() {
        audioQueue.async { [weak self] in
            guard let self else {
                return
            }
                        
            rtcAudioSession.lockForConfiguration()
            do {
                try rtcAudioSession.setCategory(
                    AVAudioSession.Category.playAndRecord,
                    with: [.duckOthers, .allowBluetooth, .allowBluetoothA2DP]
                )
                try rtcAudioSession.setMode(.voiceChat)
                try rtcAudioSession.overrideOutputAudioPort(.none)
                try rtcAudioSession.setActive(true)
            }
            catch {
                debugPrint("Error setting AVAudioSession category: \(error)")
            }
            rtcAudioSession.unlockForConfiguration()
            
            delegate?.peerConnectionClient(self, speakerActive: false)
        }
    }
    
    /// Enable the speaker for the rtc session
    func speakerOn() {
        audioQueue.async { [weak self] in
            guard let self else {
                return
            }
            
            rtcAudioSession.lockForConfiguration()
            do {
                try rtcAudioSession.setCategory(
                    AVAudioSession.Category.playAndRecord,
                    with: [.duckOthers, .allowBluetooth, .allowBluetoothA2DP]
                )
                try rtcAudioSession.setMode(AVAudioSession.Mode.videoChat)
                try rtcAudioSession.overrideOutputAudioPort(.speaker)
                try rtcAudioSession.setActive(true)
            }
            catch {
                debugPrint("Couldn't force audio to speaker: \(error)")
            }
            rtcAudioSession.unlockForConfiguration()
            
            delegate?.peerConnectionClient(self, speakerActive: true)
        }
    }
    
    /// Set the audio track for the peer connection
    private func setAudioEnabled(_ isEnabled: Bool) {
        guard let peerConnection else {
            assertionFailure("\(VoIPCallPeerConnectionClientError.peerConnectionIsNotInitialized)")
            DDLogWarn("\(VoIPCallPeerConnectionClientError.peerConnectionIsNotInitialized)")
            return
        }
        
        let audioTracks = peerConnection.transceivers.compactMap { $0.sender.track as? RTCAudioTrack }
        audioTracks.forEach { $0.isEnabled = isEnabled }

        DDLogNotice(
            "VoipCallService: [cid=\(callID?.callID ?? 0)]: \(isEnabled ? "Enabled" : "Disabled") Audio for current call"
        )
    }
}

extension VoIPCallPeerConnectionClient {
    // MARK: class functions
    
    /// Configure the peer connection
    /// - parameter alwaysRelayCall: true or false, if user enabled always relay call setting
    /// - returns: RTCConfiguration for the peer connection
    class func defaultRTCConfiguration(
        peerConnectionParameters: PeerConnectionParameters,
        completion: @escaping (Swift.Result<RTCConfiguration, Error>) -> Void
    ) {
        // forceTurn determines whether to use dual stack enabled TURN servers.
        // In normal mode, the device is either:
        // a) IPv4 only or dual stack. It can then be reached directly or via relaying over IPv4 TURN servers.
        // b) IPv6 only and then **must** be reachable via a peer-to-peer connection.
        //
        // When enforcing relayed mode, the device may have an IPv6 only configuration, so we need to be able
        // to reach our TURN servers via IPv6 or no connection can be established at all.
        VoIPIceServerSource.obtainIceServers(dualStack: peerConnectionParameters.forceTurn) { result in
            do {
                let configuration = RTCConfiguration()
                configuration.iceServers = try [result.get()]
                if peerConnectionParameters.forceTurn == true {
                    configuration.iceTransportPolicy = .relay
                }
                configuration.bundlePolicy = .maxBundle
                configuration.rtcpMuxPolicy = .require
                configuration.tcpCandidatePolicy = .disabled
                configuration.sdpSemantics = .unifiedPlan
                configuration.continualGatheringPolicy = peerConnectionParameters
                    .gatherContinually ? .gatherContinually : .gatherOnce
                configuration.keyType = .ECDSA
                configuration.cryptoOptions = RTCCryptoOptions(
                    srtpEnableGcmCryptoSuites: true,
                    srtpEnableAes128Sha1_32CryptoCipher: false,
                    srtpEnableAes128Sha1_80CryptoCipher: false,
                    srtpEnableEncryptedRtpHeaderExtensions: true,
                    sframeRequireFrameEncryption: false
                )
                configuration.offerExtmapAllowMixed = true
                
                completion(.success(configuration))
            }
            catch {
                completion(.failure(error))
            }
        }
    }
    
    /// Get the rtc media constraints for the peer connection
    /// - returns: RTCMediaConstraints for the peer connection
    class func defaultPeerConnectionConstraints() -> RTCMediaConstraints {
        let optionalConstraints = ["DtlsSrtpKeyAgreement": kRTCMediaConstraintsValueTrue]
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: optionalConstraints)
        return constraints
    }
    
    /// Get the rtc media constraints for the offer or answer
    /// - returns: RTCMediaConstraints for the offer or answer
    class func mediaConstrains(isVideoCallAvailable: Bool) -> RTCMediaConstraints {
        let mandatoryConstraints = [
            kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
            kRTCMediaConstraintsOfferToReceiveVideo: isVideoCallAvailable ? kRTCMediaConstraintsValueTrue :
                kRTCMediaConstraintsValueFalse,
        ]
        let constraints = RTCMediaConstraints(mandatoryConstraints: mandatoryConstraints, optionalConstraints: nil)

        return constraints
    }
}

extension VoIPCallPeerConnectionClient {
    // MARK: public functions
    
    func startCaptureLocalVideo(renderer: RTCVideoRenderer, useBackCamera: Bool, switchCamera: Bool = false) {
        guard let capturer = videoCapturer as? RTCCameraVideoCapturer else {
            return
        }

        let newProfile = CallsignalingProtocol.findCommonProfile(
            remoteProfile: remoteVideoQualityProfile,
            networkIsRelayed: networkIsRelayed
        )
        setOutgoingVideoLimits(
            maxBitrate: Int(newProfile.bitrate) * 1000,
            maxFps: Int(newProfile.maxFps),
            w: UInt32(newProfile.maxResolution.width),
            h: UInt32(newProfile.maxResolution.height)
        )
        
        let localCaptureQualityProfile = CallsignalingProtocol.localCaptureQualityProfile()
        if useBackCamera == true,
           let backCamera = (RTCCameraVideoCapturer.captureDevices().first { $0.position == .back }) {
            let format = selectFormatForDevice(
                device: backCamera,
                width: Int32(localCaptureQualityProfile.maxResolution.width),
                height: Int32(localCaptureQualityProfile.maxResolution.height),
                capturer: capturer
            )
            
            capturer.startCapture(
                with: backCamera,
                format: format,
                fps: Int(localCaptureQualityProfile.maxFps)
            )
        }
        else {
            guard
                let frontCamera = (RTCCameraVideoCapturer.captureDevices().first { $0.position == .front }) else {
                return
            }
            
            let format = selectFormatForDevice(
                device: frontCamera,
                width: Int32(localCaptureQualityProfile.maxResolution.width),
                height: Int32(localCaptureQualityProfile.maxResolution.height),
                capturer: capturer
            )
            capturer.startCapture(
                with: frontCamera,
                format: format,
                fps: Int(localCaptureQualityProfile.maxFps)
            )
        }
        localVideoTrack?.add(renderer)
        
        if switchCamera == false {
            if let protobufMessage = CallsignalingProtocol.encodeVideoCapture(true) {
                sendDataToRemote(protobufMessage)
            }
        }
    }
    
    func endCaptureLocalVideo(renderer: RTCVideoRenderer, switchCamera: Bool = false) {
        if switchCamera == false {
            if let protobufMessage = CallsignalingProtocol.encodeVideoCapture(false) {
                sendDataToRemote(protobufMessage)
            }
        }
    
        guard let capturer = videoCapturer as? RTCCameraVideoCapturer else {
            return
        }
        capturer.stopCapture()
        localVideoTrack?.remove(renderer)
    }
    
    func renderRemoteVideo(to renderer: RTCVideoRenderer) {
        remoteVideoTrack?.add(renderer)
    }
    
    func endRemoteVideo(renderer: RTCVideoRenderer) {
        remoteVideoTrack?.remove(renderer)
    }
    
    func stopVideoCall() {
        guard let capturer = videoCapturer as? RTCCameraVideoCapturer else {
            return
        }
        capturer.stopCapture()
        
        localVideoTrack = nil
        remoteVideoTrack = nil
    }
}

extension VoIPCallPeerConnectionClient {
    // MARK: private functions
    
    /// Get the rtc media constraints for the audio
    /// - returns: RTCMediaConstraints for the audio
    private func defaultAudioConstraints() -> RTCMediaConstraints {
        RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
    }
    
    /// Create an audio and video track and add it as local stream to the peer connection
    private func createMediaSenders() {
        guard let peerConnection, let peerConnectionParameters else {
            assertionFailure("\(VoIPCallPeerConnectionClientError.peerConnectionIsNotInitialized)")
            DDLogWarn("\(VoIPCallPeerConnectionClientError.peerConnectionIsNotInitialized)")
            return
        }

        let streamID = "3MACALL"
        
        // Audio
        let audioTrack = createAudioTrack()
        peerConnection.add(audioTrack, streamIds: [streamID])
        
        if peerConnectionParameters.isVideoCallAvailable {
            // Video
            let videoTrack = createVideoTrack()
            localVideoTrack = videoTrack
            localVideoSender = peerConnection.add(videoTrack, streamIds: [streamID])
            remoteVideoTrack = peerConnection.transceivers.first { $0.mediaType == .video }?.receiver
                .track as? RTCVideoTrack
        }
        
        if let dataChannel = createDataChannel() {
            dataChannel.delegate = self
            self.dataChannel = dataChannel
        }
    }
    
    /// Create an audio track and add it as local stream to the peer connection
    private func createAudioTrack() -> RTCAudioTrack {
        let audioConstrains = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = VoIPCallPeerConnectionClient.factory.audioSource(with: audioConstrains)
        let audioTrack = VoIPCallPeerConnectionClient.factory.audioTrack(with: audioSource, trackId: "3MACALLa0")
        return audioTrack
    }
    
    /// Create a video track and add it as local stream to the peer connection
    private func createVideoTrack() -> RTCVideoTrack {
        let videoSource = VoIPCallPeerConnectionClient.factory.videoSource()
        #if TARGET_OS_SIMULATOR
            videoCapturer = RTCFileVideoCapturer(delegate: videoSource)
        #else
            videoCapturer = RTCCameraVideoCapturer(delegate: videoSource)
        #endif
        let videoTrack = VoIPCallPeerConnectionClient.factory.videoTrack(with: videoSource, trackId: "3MACALLv0")
        return videoTrack
    }
    
    /// Create a data channel and add it to the peer connection
    private func createDataChannel() -> RTCDataChannel? {
        guard let peerConnection else {
            assertionFailure("\(VoIPCallPeerConnectionClientError.peerConnectionIsNotInitialized)")
            DDLogWarn("\(VoIPCallPeerConnectionClientError.peerConnectionIsNotInitialized)")
            return nil
        }

        let config = RTCDataChannelConfiguration()
        config.channelId = 0
        config.isNegotiated = true
        config.isOrdered = true
        guard let dataChannel = peerConnection.dataChannel(forLabel: "3MACALLdc0", configuration: config) else {
            debugPrint("Warning: Couldn't create data channel.")
            return nil
        }
        return dataChannel
    }

    /// Configure the audio session category to .playAndRecord in the mode .voiceChat
    private func configureAudioSession() {
        rtcAudioSession.lockForConfiguration()
        do {
            try rtcAudioSession.setCategory(
                AVAudioSession.Category.playAndRecord,
                with: [.duckOthers, .allowBluetooth, .allowBluetoothA2DP]
            )
            try rtcAudioSession.setMode(.voiceChat)
        }
        catch {
            debugPrint("Error changeing AVAudioSession category: \(error)")
        }
        rtcAudioSession.unlockForConfiguration()
    }
    
    /// set outgoing video limits
    private func setOutgoingVideoLimits(maxBitrate: Int, maxFps: Int, w: UInt32, h: UInt32) {
        setOutgoingVideoEncoderLimits(maxBitrate: maxBitrate, maxFps: maxFps)
        setOutgoingVideoResolution(w: w, h: h, maxFps: UInt32(maxFps))
    }
    
    /// set outgoing video encoder limits for bitrate and fps
    private func setOutgoingVideoEncoderLimits(maxBitrate: Int, maxFps: Int) {
        guard let sender = localVideoSender else {
            debugPrint("setOutgoingVideoBandwidthLimit: Could not find local video sender")
            return
        }
       
        let parameters = sender.parameters
        parameters.degradationPreference = NSNumber(value: RTCDegradationPreference.balanced.rawValue)
        for encoding in parameters.encodings {
            DDLogDebug(
                "VoipCallService: [cid=\(callID?.callID ?? 0)]: Rtp encoding before -> maxBitrateBps: \(encoding.maxBitrateBps ?? 0), maxFramerate: \(encoding.maxFramerate ?? 0)"
            )
            encoding.maxBitrateBps = NSNumber(value: maxBitrate)
            encoding.maxFramerate = NSNumber(value: maxFps)
            DDLogDebug(
                "VoipCallService: [cid=\(callID?.callID ?? 0)]: Rtp encoding after -> maxBitrateBps: \(encoding.maxBitrateBps ?? 0), maxFramerate: \(encoding.maxFramerate ?? 0)"
            )
        }
        sender.parameters = parameters
    }
    
    private func setOutgoingVideoResolution(w: UInt32, h: UInt32, maxFps: UInt32) {
        guard let videoSource = localVideoTrack?.source else {
            return
        }
        videoSource.adaptOutputFormat(toWidth: Int32(w), height: Int32(h), fps: Int32(maxFps))
    }
        
    /// Select the correct format for the capture device
    private func selectFormatForDevice(
        device: AVCaptureDevice,
        width: Int32,
        height: Int32,
        capturer: RTCCameraVideoCapturer
    ) -> AVCaptureDevice.Format {
        let targetHeight = height
        let targetWidth = width
        
        var selectedFormat: AVCaptureDevice.Format?
        var currentDiff = Int32.max
        
        let supportedFormats = RTCCameraVideoCapturer.supportedFormats(for: device)
        
        for format in supportedFormats {
            let dimension: CMVideoDimensions = CMVideoFormatDescriptionGetDimensions(
                format.formatDescription
            )
            let diff =
                abs(targetWidth - dimension.width) +
                abs(targetHeight - dimension.height)
            let pixelFormat = CMFormatDescriptionGetMediaSubType(format.formatDescription)
            if diff < currentDiff {
                selectedFormat = format
                currentDiff = diff
            }
            else if diff == currentDiff, pixelFormat == capturer.preferredOutputPixelFormat() {
                selectedFormat = format
            }
        }
        
        return selectedFormat!
    }

    private func sendDataToRemote(_ data: Data) {
        guard let peerConnectionParameters else {
            assertionFailure("\(VoIPCallPeerConnectionClientError.peerConnectionIsNotInitialized)")
            DDLogWarn("\(VoIPCallPeerConnectionClientError.peerConnectionIsNotInitialized)")
            return
        }

        if peerConnectionParameters.isDataChannelAvailable {
            sendCachedDataChannelDataToRemote()
            let buffer = RTCDataBuffer(data: data, isBinary: true)
            dataChannel?.sendData(buffer)
        }
        else {
            dataChannelLockQueue.sync {
                dataChannelQueue.enqueue(data)
            }
        }
    }
    
    private func sendCachedDataChannelDataToRemote() {
        while !dataChannelQueue.elements.isEmpty {
            var element: Data?
            dataChannelLockQueue.sync {
                element = dataChannelQueue.dequeue() as? Data
            }
            if element != nil {
                let buffer = RTCDataBuffer(data: element!, isBinary: true)
                dataChannel?.sendData(buffer)
            }
        }
    }
    
    private func setQualityProfileForVideoSource() {
        let newProfile = CallsignalingProtocol.findCommonProfile(
            remoteProfile: remoteVideoQualityProfile,
            networkIsRelayed: networkIsRelayed
        )
        setOutgoingVideoLimits(
            maxBitrate: Int(newProfile.bitrate) * 1000,
            maxFps: Int(newProfile.maxFps),
            w: UInt32(newProfile.maxResolution.width),
            h: UInt32(newProfile.maxResolution.height)
        )
        if let protobufMessage = CallsignalingProtocol
            .encodeVideoQuality(CallsignalingProtocol.localPeerQualityProfile().profile!) {
            sendDataToRemote(protobufMessage)
        }
    }
}

extension VoIPCallPeerConnectionClient {
    // MARK: Signaling

    func offer(completion: @escaping (_ sdp: RTCSessionDescription?, _ error: VoIPCallSdpPatcher.SdpError?) -> Void) {
        guard let peerConnection, let peerConnectionParameters else {
            assertionFailure("\(VoIPCallPeerConnectionClientError.peerConnectionIsNotInitialized)")
            DDLogWarn("\(VoIPCallPeerConnectionClientError.peerConnectionIsNotInitialized)")
            return
        }

        let constrains = VoIPCallPeerConnectionClient
            .mediaConstrains(isVideoCallAvailable: peerConnectionParameters.isVideoCallAvailable)
        peerConnection.offer(for: constrains) { sdp, _ in
            guard let sdp else {
                completion(nil, nil)
                return
            }
            
            DispatchQueue.main.async {
                guard let contact = BusinessInjector.ui.entityManager.entityFetcher.contact(for: self.contactIdentity)
                else {
                    completion(nil, nil)
                    return
                }
                
                let bContact = Contact(contactEntity: contact)
                let extensionConfig: VoIPCallSdpPatcher.RtpHeaderExtensionConfig = FeatureMask.check(
                    contact: bContact,
                    for: .o2OVideoCallSupport
                ) ? .ENABLE_WITH_ONE_AND_TWO_BYTE_HEADER : .DISABLE
                do {
                    let patchedSdpString = try VoIPCallSdpPatcher(extensionConfig)
                        .patch(type: .LOCAL_OFFER, sdp: sdp.sdp)
                    let patchedSdp = RTCSessionDescription(type: sdp.type, sdp: patchedSdpString)
                    peerConnection.setLocalDescription(patchedSdp, completionHandler: { _ in
                        completion(patchedSdp, nil)
                    })
                }
                catch let sdpError {
                    completion(nil, sdpError as? VoIPCallSdpPatcher.SdpError)
                }
            }
        }
    }
    
    func answer(completion: @escaping (_ sdp: RTCSessionDescription) -> Void) {
        guard let peerConnection, let peerConnectionParameters else {
            assertionFailure("\(VoIPCallPeerConnectionClientError.peerConnectionIsNotInitialized)")
            DDLogWarn("\(VoIPCallPeerConnectionClientError.peerConnectionIsNotInitialized)")
            return
        }

        let constrains = VoIPCallPeerConnectionClient
            .mediaConstrains(isVideoCallAvailable: peerConnectionParameters.isVideoCallAvailable)
        peerConnection.answer(for: constrains) { sdp, _ in
            guard let sdp else {
                return
            }
            
            peerConnection.setLocalDescription(sdp, completionHandler: { _ in
                completion(sdp)
            })
        }
    }
    
    func set(remoteSdp: RTCSessionDescription, completion: @escaping (Error?) -> Void) {
        guard let peerConnection else {
            assertionFailure("\(VoIPCallPeerConnectionClientError.peerConnectionIsNotInitialized)")
            DDLogWarn("\(VoIPCallPeerConnectionClientError.peerConnectionIsNotInitialized)")
            return
        }

        delegate?.peerconnectionClient(self, startTransportExpectedStableTimer: true)
        peerConnection.setRemoteDescription(remoteSdp, completionHandler: completion)
    }
    
    func set(addRemoteCandidate: RTCIceCandidate) {
        guard let peerConnection else {
            assertionFailure("\(VoIPCallPeerConnectionClientError.peerConnectionIsNotInitialized)")
            DDLogWarn("\(VoIPCallPeerConnectionClientError.peerConnectionIsNotInitialized)")
            return
        }

        peerConnection.add(addRemoteCandidate) { error in
            if error != nil {
                DDLogNotice(
                    "VoipCallService: [cid=\(self.callID?.callID ?? 0)]: Can't add remote ICE candidate \(addRemoteCandidate.sdp)"
                )
                return
            }
        }
    }
    
    func set(removeRemoteCandidates: [RTCIceCandidate]) {
        guard let peerConnection else {
            assertionFailure("\(VoIPCallPeerConnectionClientError.peerConnectionIsNotInitialized)")
            DDLogWarn("\(VoIPCallPeerConnectionClientError.peerConnectionIsNotInitialized)")
            return
        }

        peerConnection.remove(removeRemoteCandidates)
    }
}

// MARK: - RTCPeerConnectionDelegate

extension VoIPCallPeerConnectionClient: RTCPeerConnectionDelegate {
    // MARK: RTCPeerConnectionDelegates

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        DDLogNotice(
            "VoipCallService: [cid=\(callID?.callID ?? 0)]: Signaling state change to \(stateChanged.debugDescription)"
        )
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        DDLogNotice("VoipCallService: [cid=\(callID?.callID ?? 0)]: Did add stream")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        DDLogNotice("VoipCallService: [cid=\(callID?.callID ?? 0)]: Did remove stream")
    }

    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        DDLogNotice("VoipCallService: [cid=\(callID?.callID ?? 0)]: Renegotiation needed")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCPeerConnectionState) {
        guard let peerConnectionParameters else {
            assertionFailure("Peer connection is not initialized")
            return
        }

        DDLogNotice(
            "VoipCallService: [cid=\(callID?.callID ?? 0)]: Peer connection state change to \(newState.debugDescription)"
        )
        
        if newState == .connecting {
            // Schedule 'connecting' stats timer
            let options = VoIPStatsOptions()
            options.selectedCandidatePair = true
            options.transport = true
            options.crypto = true
            options.inboundRtp = true
            options.outboundRtp = true
            options.tracks = true
            options.candidatePairsFlag = .OVERVIEW_AND_DETAILED
            schedulePeriodStats(options: options, period: VoIPCallPeerConnectionClient.logStatsIntervalConnecting)
        }
        
        if VoIPCallStateManager.shared.currentCallState() == .initializing,
           newState == .connected {
            let options = VoIPStatsOptions()
            options.selectedCandidatePair = true
            options.transport = true
            options.crypto = true
            options.inboundRtp = true
            options.outboundRtp = true
            options.tracks = true
            options.candidatePairsFlag = .OVERVIEW
            schedulePeriodStats(options: options, period: VoIPCallPeerConnectionClient.logStatsIntervalConnected)
            
            if peerConnectionParameters.isVideoCallAvailable {
                let receivedVideoOptions = VoIPStatsOptions()
                receivedVideoOptions.framesReceived = true
                receivedVideoOptions.selectedCandidatePair = true
                scheduleVideoStats(
                    options: receivedVideoOptions,
                    period: VoIPCallPeerConnectionClient.checkReceivingVideoInterval
                )
            }
        }
        
        delegate?.peerConnectionClient(self, didChangeConnectionState: newState)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        DDLogNotice(
            "VoipCallService: [cid=\(callID?.callID ?? 0)]: ICE connection state change to \(newState.debugDescription)"
        )
    }
        
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        DDLogNotice(
            "VoipCallService: [cid=\(callID?.callID ?? 0)]: ICE gathering state change to \(newState.debugDescription)"
        )
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        DDLogNotice("VoipCallService: [cid=\(callID?.callID ?? 0)]: New local ICE candidate: \(candidate.sdp)")
        delegate?.peerConnectionClient(self, addedCandidate: candidate)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        // Log is in the delegate
        delegate?.peerConnectionClient(self, removedCandidates: candidates)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        DDLogNotice(
            "VoipCallService: [cid=\(callID?.callID ?? 0)]: New data channel: (\(dataChannel.label)) (id=\(dataChannel.channelId))"
        )
    }
}

// MARK: - RTCDataChannelDelegate

extension VoIPCallPeerConnectionClient: RTCDataChannelDelegate {
    // MARK: RTCDataChannelDelegate

    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        guard peerConnectionParameters != nil else {
            assertionFailure("\(VoIPCallPeerConnectionClientError.peerConnectionIsNotInitialized)")
            DDLogWarn("\(VoIPCallPeerConnectionClientError.peerConnectionIsNotInitialized)")
            return
        }

        peerConnectionParameters?.isDataChannelAvailable = dataChannel.readyState == .open
        sendCachedDataChannelDataToRemote()
    }
    
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        delegate?.peerConnectionClient(self, didReceiveData: buffer.data)
    }
}

extension VoIPCallPeerConnectionClient {
    // MARK: VoIP Stats
    
    func schedulePeriodStats(options: VoIPStatsOptions, period: TimeInterval) {
        guard let peerConnection else {
            assertionFailure("\(VoIPCallPeerConnectionClientError.peerConnectionIsNotInitialized)")
            DDLogWarn("\(VoIPCallPeerConnectionClientError.peerConnectionIsNotInitialized)")
            return
        }

        // check on main thread for statsTimer
        DispatchQueue.main.async {
            if self.statsTimer != nil {
                self.statsTimer?.invalidate()
                self.statsTimer = nil
            }
        }
        // Create new timer with <period> (but immediately log once)
        var dict = [AnyHashable: Any]()
        dict.updateValue(peerConnection, forKey: "connection")
        dict.updateValue(options, forKey: "options")
        logDebugStats(dict: dict)
        DispatchQueue.main.async {
            self.statsTimer = Timer.scheduledTimer(withTimeInterval: period, repeats: true, block: { _ in
                self.logDebugStats(dict: dict)
            })
        }
    }
    
    func scheduleVideoStats(options: VoIPStatsOptions, period: TimeInterval) {
        DispatchQueue.main.async {
            if self.receivingVideoTimer != nil {
                self.receivingVideoTimer?.invalidate()
                self.receivingVideoTimer = nil
            }
        }
        
        // Create new timer with <period>
        var dict = [AnyHashable: Any]()
        dict.updateValue(peerConnection, forKey: "connection")
        dict.updateValue(options, forKey: "options")
        checkIsReceivingVideo(dict: dict)
        DispatchQueue.main.async {
            self.receivingVideoTimer = Timer.scheduledTimer(withTimeInterval: period, repeats: true, block: { _ in
                self.checkIsReceivingVideo(dict: dict)
            })
        }
    }
    
    func logDebugEndStats(completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            if self.receivingVideoTimer != nil {
                self.receivingVideoTimer?.invalidate()
                self.receivingVideoTimer = nil
            }
        }
        if statsTimer != nil {
            DispatchQueue.main.async {
                self.statsTimer?.invalidate()
                self.statsTimer = nil
            }
            
            // Hijack the existing dict, override options and set callback
            let options = VoIPStatsOptions()
            options.selectedCandidatePair = false
            options.transport = true
            options.crypto = true
            options.inboundRtp = true
            options.outboundRtp = true
            options.tracks = true
            options.candidatePairsFlag = .OVERVIEW_AND_DETAILED
            
            // One-shot stats fetch before disconnect
            logDebugStats(dict: ["connection": peerConnection, "options": options, "callback": completion])
        }
        else {
            completion()
        }
    }
    
    func logDebugStats(dict: [AnyHashable: Any]) {
        guard let peerConnectionParameters else {
            assertionFailure("Peer connection is not initialized")
            return
        }

        let connection = dict["connection"] as! RTCPeerConnection
        let options = dict["options"] as! VoIPStatsOptions
                
        connection.statistics { report in
            let stats = VoIPStats(
                report: report,
                options: options,
                transceivers: connection.transceivers,
                previousState: self.previousPeriodDebugState
            )
            self.previousPeriodDebugState = stats.buildVoIPStatsState()
            self.networkIsRelayed = stats.usesRelay()

            var statsString = stats.getRepresentation()
            statsString +=
                "\n\(CallsignalingProtocol.printDebugQualityProfiles(remoteProfile: self.remoteVideoQualityProfile, networkIsRelayed: self.networkIsRelayed))"
            DDLogNotice("VoipCallService: [cid=\(self.callID?.callID ?? 0)]: Stats: \n \(statsString)")
            
            // this is only needed if video calls are not available
            if !peerConnectionParameters.isVideoCallAvailable {
                self.checkIsSelectedCandidatePairCellular(stats: stats)
            }

            if let callback = dict["callback"] as? (() -> Void) {
                callback()
            }
        }
    }
    
    func checkIsReceivingVideo(dict: [AnyHashable: Any]) {
        let connection = dict["connection"] as! RTCPeerConnection
        let options = dict["options"] as! VoIPStatsOptions
        
        connection.statistics { report in
            let stats = VoIPStats(
                report: report,
                options: options,
                transceivers: connection.transceivers,
                previousState: self.previousVideoState
            )
            self.previousVideoState = stats.buildVoIPStatsState()
            
            if !self.isRemoteVideoActivated {
                self.delegate?.peerConnectionClient(self, receivingVideo: stats.isReceivingVideo())
            }
            self.checkIsSelectedCandidatePairCellular(stats: stats)
        }
        if isRemoteVideoActivated {
            delegate?.peerConnectionClient(self, receivingVideo: true)
        }
    }
    
    func checkIsSelectedCandidatePairCellular(stats: VoIPStats) {
        isSelectedCandidatePairCellular = stats.isSelectedCandidatePairCellular()
    }
}

extension VoIPCallPeerConnectionClient {
    // MARK: Network Status Changed
    
    @objc func networkStatusDidChange(notice: Notification) {
        if CallsignalingProtocol.isThreemaVideoCallQualitySettingAuto() {
            let currentInternetStatus = internetReachability.connection
            if lastInternetStatus != currentInternetStatus {
                lastInternetStatus = currentInternetStatus
                setQualityProfileForVideoSource()
            }
        }
    }
}
