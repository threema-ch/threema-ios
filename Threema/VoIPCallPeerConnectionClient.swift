//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2021 Threema GmbH
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
import AVFoundation
import WebRTC
import ThreemaFramework
import CocoaLumberjackSwift

protocol VoIPCallPeerConnectionClientDelegate: class {
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClient, changeState: VoIPCallService.CallState)
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClient, audioMuted: Bool)
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClient, speakerActive: Bool)
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClient, removedCandidates: [RTCIceCandidate])
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClient, addedCandidate: RTCIceCandidate)
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClient, didChangeConnectionState state: RTCIceConnectionState)
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClient, receivingVideo: Bool)
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClient, didReceiveData: Data)
    func peerConnectionClient(_ client: VoIPCallPeerConnectionClient, shouldShowCellularCallWarning: Bool)
}


final class VoIPCallPeerConnectionClient: NSObject {
    
    // The `RTCPeerConnectionFactory` is in charge of creating new RTCPeerConnection instances.
    // A new RTCPeerConnection should be created every new call, but the factory is shared.
    private static var factory: RTCPeerConnectionFactory = {
        let decoderFactory = RTCDefaultVideoDecoderFactory()
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        return RTCPeerConnectionFactory(encoderFactory: encoderFactory, decoderFactory: decoderFactory)
    }()
        
    weak var delegate: VoIPCallPeerConnectionClientDelegate?
    let peerConnection: RTCPeerConnection
    
    var remoteVideoQualityProfile: CallsignalingProtocol.ThreemaVideoCallQualityProfile? {
        didSet {
            let newProfile = CallsignalingProtocol.findCommonProfile(remoteProfile: remoteVideoQualityProfile, networkIsRelayed: networkIsRelayed)
            self.setOutgoingVideoLimits(maxBitrate: Int(newProfile.bitrate) * 1000, maxFps: Int(newProfile.maxFps), w: UInt32(newProfile.maxResolution.width), h: UInt32(newProfile.maxResolution.height))
        }
    }
    var isRemoteVideoActivated: Bool = false {
        didSet {
             self.delegate?.peerConnectionClient(self, receivingVideo: true)
        }
    }
    
    private var peerConnectionParameters: PeerConnectionParameters
    
    private let rtcAudioSession =  RTCAudioSession.sharedInstance()
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
    
    private var contact: Contact?
    
    private let internetReachability: Reachability = Reachability.forInternetConnection()
    private var lastInternetStatus: NetworkStatus?
    private(set) var networkIsRelayed: Bool = false // will be checked every 30 seconds after connection is established
    
    private var previousPeriodDebugState: VoIPStatsState? = nil
    private var previousVideoState: VoIPStatsState? = nil
    
    private var callId: VoIPCallId? = nil
    
    private var isSelectedCandidatePairCellular: Bool = false {
        didSet {
            let shouldShowCellularCallWarning = isSelectedCandidatePairCellular && lastInternetStatus == ReachableViaWiFi
            self.delegate?.peerConnectionClient(self, shouldShowCellularCallWarning: shouldShowCellularCallWarning)
        }
    }
    
    private static let logStatsIntervalConnecting = 2.0
    private static let logStatsIntervalConnected = 30.0
    private static let checkReceivingVideoInterval = 2.0
    
    private var videoCallQualityObserver: NSObjectProtocol?
    
    private let webrtcLogger = RTCCallbackLogger()

    
    public struct PeerConnectionParameters {
        public var isVideoCallAvailable: Bool = true
        public var videoCodecHwAcceleration: Bool = true
        public var forceTurn: Bool = false
        public var gatherContinually: Bool = false
        public var allowIpv6: Bool = true
        
        internal var isDataChannelAvailable: Bool = false
    }
    
    static func instantiate(contact: Contact, callId: VoIPCallId?, peerConnectionParameters: PeerConnectionParameters, completion: @escaping (Result<VoIPCallPeerConnectionClient,Error>) -> Void) {
        VoIPCallPeerConnectionClient.defaultRTCConfiguration(peerConnectionParameters: peerConnectionParameters) { (result) in
            do {
                let client = VoIPCallPeerConnectionClient.init(contact: contact, callId: callId, peerConnectionParameters: peerConnectionParameters, config: try result.get())
                completion(.success(client))
            } catch let e {
                completion(.failure(e))
            }
        }
    }
    
    /**
     Init new peer connection with a contact
     - parameter contact: Call contact
     */
    required init(contact: Contact, callId: VoIPCallId?, peerConnectionParameters: PeerConnectionParameters, config: RTCConfiguration) {
        webrtcLogger.severity = .warning
        webrtcLogger.start { (message) in
            DDLogNotice("libwebrtc: \(message)")
        }
        self.peerConnectionParameters = peerConnectionParameters
        let constraints = VoIPCallPeerConnectionClient.defaultPeerConnectionConstraints()
        peerConnection = VoIPCallPeerConnectionClient.factory.peerConnection(with: config, constraints: constraints, delegate: nil)!
        self.contact = contact
        self.callId = callId
        super.init()
        self.createMediaSenders()
        configureAudioSession()
        peerConnection.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(networkStatusDidChange), name: NSNotification.Name.reachabilityChanged, object: nil)
        videoCallQualityObserver = NotificationCenter.default.addObserver(forName: Notification.Name(kThreemaVideoCallsQualitySettingChanged), object: nil, queue: nil) { [weak self] notification in
            guard let self = self else { return }
            self.setQualityProfileForVideoSource()
        }
        if let protobufMessage = CallsignalingProtocol.encodeVideoQuality(CallsignalingProtocol.localPeerQualityProfile().profile!) {
            sendDataToRemote(protobufMessage)
        }
        internetReachability.startNotifier()
        lastInternetStatus = internetReachability.currentReachabilityStatus()
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
}

extension VoIPCallPeerConnectionClient {
    // MARK:- Audio control
    
    /**
     Mute the audio of the rtc session
     */
    func muteAudio(completion: @escaping () -> ()) {
        setAudioEnabled(false)
        delegate?.peerConnectionClient(self, audioMuted: true)
        if let protobufMessage = CallsignalingProtocol.encodeMute(true) {
            sendDataToRemote(protobufMessage)
        }
        completion()
    }
    
    /**
     Unmute the audio of the rtc session
     */
    func unmuteAudio(completion: @escaping () -> ()) {
        setAudioEnabled(true)
        delegate?.peerConnectionClient(self, audioMuted: false)
        if let protobufMessage = CallsignalingProtocol.encodeMute(false) {
            sendDataToRemote(protobufMessage)
        }
        completion()
    }
    
    /**
     Activate RTC audio
     */
    func activateRTCAudio(speakerActive: Bool) {
        audioQueue.async { [weak self] in
            guard let self = self else {
                return
            }
            self.rtcAudioSession.lockForConfiguration()
            do {
                try self.rtcAudioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue, with: [.duckOthers, .allowBluetooth, .allowBluetoothA2DP])
                try self.rtcAudioSession.setMode(AVAudioSession.Mode.voiceChat.rawValue)
                try self.rtcAudioSession.overrideOutputAudioPort(speakerActive ? .speaker : .none)
                try self.rtcAudioSession.setActive(true)
            } catch let error {
                debugPrint("Error setting AVAudioSession category: \(error)")
            }
            self.rtcAudioSession.unlockForConfiguration()
                        
            self.rtcAudioSession.isAudioEnabled = true
        }
    }
    
    /**
     Disable the speaker for the rtc session
     */
    func speakerOff() {
        audioQueue.async { [weak self] in
            guard let self = self else {
                return
            }
                        
            self.rtcAudioSession.lockForConfiguration()
            do {
                try self.rtcAudioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue, with: [.allowBluetooth, .allowBluetoothA2DP])
                try self.rtcAudioSession.setMode(AVAudioSession.Mode.voiceChat.rawValue)
                try self.rtcAudioSession.overrideOutputAudioPort(.none)
                try self.rtcAudioSession.setActive(true)
            } catch let error {
                debugPrint("Error setting AVAudioSession category: \(error)")
            }
            self.rtcAudioSession.unlockForConfiguration()
            
            self.delegate?.peerConnectionClient(self, speakerActive: false)
        }
    }
    
    /**
     Enable the speaker for the rtc session
     */
    func speakerOn() {
        audioQueue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            self.rtcAudioSession.lockForConfiguration()
            do {
                try self.rtcAudioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue, with: [.allowBluetooth, .allowBluetoothA2DP])
                try self.rtcAudioSession.setMode(AVAudioSession.Mode.videoChat.rawValue)
                try self.rtcAudioSession.overrideOutputAudioPort(.speaker)
                try self.rtcAudioSession.setActive(true)
            } catch let error {
                debugPrint("Couldn't force audio to speaker: \(error)")
            }
            self.rtcAudioSession.unlockForConfiguration()
            
            self.delegate?.peerConnectionClient(self, speakerActive: true)
        }
    }
    
    /**
     Set the audio track for the peer connection
     */
    private func setAudioEnabled(_ isEnabled: Bool) {
        
        let audioTracks = self.peerConnection.transceivers.compactMap { return $0.sender.track as? RTCAudioTrack }
        audioTracks.forEach { $0.isEnabled = isEnabled }

        DDLogNotice("VoipCallService: [cid=\(self.callId?.callId ?? 0)]: \(isEnabled ? "Enabled" : "Disabled") Audio for current call")
    }
}

extension VoIPCallPeerConnectionClient {
    // MARK: class functions
    
    /**
     Configure the peer connection
     - parameter alwaysRelayCall: true or false, if user enabled always relay call setting
     - returns: RTCConfiguration for the peer connection
     */
    internal class func defaultRTCConfiguration(peerConnectionParameters: PeerConnectionParameters, completion: @escaping (Result<RTCConfiguration,Error>) -> Void) {
        // forceTurn determines whether to use dual stack enabled TURN servers.
        // In normal mode, the device is either:
        // a) IPv4 only or dual stack. It can then be reached directly or via relaying over IPv4 TURN servers.
        // b) IPv6 only and then **must** be reachable via a peer-to-peer connection.
        //
        // When enforcing relayed mode, the device may have an IPv6 only configuration, so we need to be able
        // to reach our TURN servers via IPv6 or no connection can be established at all.
        VoIPIceServerSource.obtainIceServers(dualStack: peerConnectionParameters.forceTurn) { (result) in
            do {
                let configuration = RTCConfiguration.init()
                configuration.iceServers = [try result.get()]
                if peerConnectionParameters.forceTurn == true {
                    configuration.iceTransportPolicy = .relay
                }
                configuration.bundlePolicy = .maxBundle
                configuration.rtcpMuxPolicy = .require
                configuration.tcpCandidatePolicy = .disabled
                configuration.sdpSemantics = .unifiedPlan
                configuration.continualGatheringPolicy = peerConnectionParameters.gatherContinually ? .gatherContinually : .gatherOnce
                configuration.keyType = .ECDSA
                configuration.cryptoOptions = RTCCryptoOptions(srtpEnableGcmCryptoSuites: true, srtpEnableAes128Sha1_32CryptoCipher: false, srtpEnableAes128Sha1_80CryptoCipher: false, srtpEnableEncryptedRtpHeaderExtensions: true, sframeRequireFrameEncryption: false)
                configuration.offerExtmapAllowMixed = true
                
                completion(.success(configuration))
            } catch let error {
                completion(.failure(error))
            }
        }
    }
    
    /**
     Get the rtc media constraints for the peer connection
     - returns: RTCMediaConstraints for the peer connection
     */
    internal class func defaultPeerConnectionConstraints() -> RTCMediaConstraints {
        let optionalConstraints = ["DtlsSrtpKeyAgreement": kRTCMediaConstraintsValueTrue]
        let constraints = RTCMediaConstraints.init(mandatoryConstraints: nil, optionalConstraints: optionalConstraints)
        return constraints
    }
    
    /**
     Get the rtc media constraints for the offer or answer
     - returns: RTCMediaConstraints for the offer or answer
     */
    internal class func mediaConstrains(isVideoCallAvailable: Bool) -> RTCMediaConstraints {
        let mandatoryConstraints = [kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue, kRTCMediaConstraintsOfferToReceiveVideo: isVideoCallAvailable ? kRTCMediaConstraintsValueTrue : kRTCMediaConstraintsValueFalse]
        let constraints = RTCMediaConstraints(mandatoryConstraints: mandatoryConstraints, optionalConstraints: nil)

        return constraints
    }
}

extension VoIPCallPeerConnectionClient {
    // MARK: public functions
    
    func startCaptureLocalVideo(renderer: RTCVideoRenderer, useBackCamera: Bool, switchCamera: Bool = false) {
        guard let capturer = self.videoCapturer as? RTCCameraVideoCapturer else {
            return
        }

        let newProfile = CallsignalingProtocol.findCommonProfile(remoteProfile: self.remoteVideoQualityProfile, networkIsRelayed: networkIsRelayed)
        self.setOutgoingVideoLimits(maxBitrate: Int(newProfile.bitrate) * 1000, maxFps: Int(newProfile.maxFps), w: UInt32(newProfile.maxResolution.width), h: UInt32(newProfile.maxResolution.height))
        
        let localCaptureQualityProfile = CallsignalingProtocol.localCaptureQualityProfile()
        if useBackCamera == true, let backCamera = (RTCCameraVideoCapturer.captureDevices().first { $0.position == .back }) {
            let format = selectFormatForDevice(device: backCamera, width: Int32(localCaptureQualityProfile.maxResolution.width), height: Int32(localCaptureQualityProfile.maxResolution.height), capturer: capturer)
            
            capturer.startCapture(with: backCamera,
            format: format,
            fps: Int(localCaptureQualityProfile.maxFps))
        } else {
            guard
                let frontCamera = (RTCCameraVideoCapturer.captureDevices().first { $0.position == .front }) else {
                    return
            }
            let format = selectFormatForDevice(device: frontCamera, width: Int32(localCaptureQualityProfile.maxResolution.width), height: Int32(localCaptureQualityProfile.maxResolution.height), capturer: capturer)
    
            capturer.startCapture(with: frontCamera,
            format: format,
            fps: Int(localCaptureQualityProfile.maxFps))
        }
        self.localVideoTrack?.add(renderer)
        
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
    
        guard let capturer = self.videoCapturer as? RTCCameraVideoCapturer else {
            return
        }
        capturer.stopCapture()
        self.localVideoTrack?.remove(renderer)
    }
    
    func renderRemoteVideo(to renderer: RTCVideoRenderer) {
        self.remoteVideoTrack?.add(renderer)
    }
    
    func endRemoteVideo(renderer: RTCVideoRenderer) {
        self.remoteVideoTrack?.remove(renderer)
    }
    
    func stopVideoCall() {
        guard let capturer = self.videoCapturer as? RTCCameraVideoCapturer else {
            return
        }
        capturer.stopCapture()
        
        localVideoTrack = nil
        remoteVideoTrack = nil
    }
}

extension VoIPCallPeerConnectionClient {
    // MARK: private functions
    
    /**
     Get the rtc media constraints for the audio
     - returns: RTCMediaConstraints for the audio
     */
    private func defaultAudioConstraints() -> RTCMediaConstraints {
        return RTCMediaConstraints.init(mandatoryConstraints: nil, optionalConstraints: nil)
    }
    
    /**
    Create an audio and video track and add it as local stream to the peer connection
    */
    private func createMediaSenders() {
        let streamId = "3MACALL"
        
        // Audio
        let audioTrack = self.createAudioTrack()
        self.peerConnection.add(audioTrack, streamIds: [streamId])
        
        if peerConnectionParameters.isVideoCallAvailable {
            // Video
            let videoTrack = self.createVideoTrack()
            self.localVideoTrack = videoTrack
            self.localVideoSender = self.peerConnection.add(videoTrack, streamIds: [streamId])
            self.remoteVideoTrack = self.peerConnection.transceivers.first { $0.mediaType == .video }?.receiver.track as? RTCVideoTrack
        }
        
        if let dataChannel = createDataChannel() {
            dataChannel.delegate = self
            self.dataChannel = dataChannel
        }
    }
    
    /**
     Create an audio track and add it as local stream to the peer connection
     */
    private func createAudioTrack()  -> RTCAudioTrack {
        let audioConstrains = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = VoIPCallPeerConnectionClient.factory.audioSource(with: audioConstrains)
        let audioTrack = VoIPCallPeerConnectionClient.factory.audioTrack(with: audioSource, trackId: "3MACALLa0")
        return audioTrack
    }
    
    /**
     Create a video track and add it as local stream to the peer connection
     */
    private func createVideoTrack() -> RTCVideoTrack {
        let videoSource = VoIPCallPeerConnectionClient.factory.videoSource()
        #if TARGET_OS_SIMULATOR
        self.videoCapturer = RTCFileVideoCapturer(delegate: videoSource)
        #else
        self.videoCapturer = RTCCameraVideoCapturer(delegate: videoSource)
        #endif
        let videoTrack = VoIPCallPeerConnectionClient.factory.videoTrack(with: videoSource, trackId: "3MACALLv0")
        return videoTrack
    }
    
    /**
    Create a data channel and add it to the peer connection
    */
    private func createDataChannel() -> RTCDataChannel? {
        let config = RTCDataChannelConfiguration()
        config.channelId = 0
        config.isNegotiated = true
        config.isOrdered = true
        guard let dataChannel = self.peerConnection.dataChannel(forLabel: "3MACALLdc0", configuration: config) else {
            debugPrint("Warning: Couldn't create data channel.")
            return nil
        }
        return dataChannel
    }

    
    /**
     Configure the audio session category to .playAndRecord in the mode .voiceChat
     */
    private func configureAudioSession() {
        self.rtcAudioSession.lockForConfiguration()
        do {
            try self.rtcAudioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue, with: [.duckOthers, .allowBluetooth, .allowBluetoothA2DP])
            try self.rtcAudioSession.setMode(AVAudioSession.Mode.voiceChat.rawValue)
        } catch let error {
            debugPrint("Error changeing AVAudioSession category: \(error)")
        }
        self.rtcAudioSession.unlockForConfiguration()
    }
    
    /**
    set outgoing video limits
    */
    private func setOutgoingVideoLimits(maxBitrate: Int, maxFps: Int, w: UInt32, h: UInt32) {
        setOutgoingVideoEncoderLimits(maxBitrate: maxBitrate, maxFps: maxFps)
        setOutgoingVideoResolution(w: w, h: h, maxFps: UInt32(maxFps))
    }
    
    /**
    set outgoing video encoder limits for bitrate and fps
    */
    private func setOutgoingVideoEncoderLimits(maxBitrate: Int, maxFps: Int) {
        guard let sender = localVideoSender else {
            debugPrint("setOutgoingVideoBandwidthLimit: Could not find local video sender")
            return
        }
       
        let parameters = sender.parameters
        parameters.degradationPreference = NSNumber(value: RTCDegradationPreference.balanced.rawValue)
        for encoding in parameters.encodings {
            DDLogDebug("VoipCallService: [cid=\(self.callId?.callId ?? 0)]: Rtp encoding before -> maxBitrateBps: \(encoding.maxBitrateBps ?? 0), maxFramerate: \(encoding.maxFramerate ?? 0)")
            encoding.maxBitrateBps = NSNumber(value: maxBitrate)
            encoding.maxFramerate = NSNumber(value: maxFps)
            DDLogDebug("VoipCallService: [cid=\(self.callId?.callId ?? 0)]: Rtp encoding after -> maxBitrateBps: \(encoding.maxBitrateBps ?? 0), maxFramerate: \(encoding.maxFramerate ?? 0)")
        }
        sender.parameters = parameters
    }
    
    private func setOutgoingVideoResolution(w: UInt32, h: UInt32, maxFps: UInt32) {
        guard let videoSource = self.localVideoTrack?.source else {
            return
        }
        videoSource.adaptOutputFormat(toWidth: Int32(w), height: Int32(h), fps: Int32(maxFps))
    }
        
    /**
    Select the correct format for the capture device
    */
    private func selectFormatForDevice(device: AVCaptureDevice, width: Int32, height: Int32, capturer: RTCCameraVideoCapturer) -> AVCaptureDevice.Format {
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
            if (diff < currentDiff) {
                selectedFormat = format
                currentDiff = diff
            }else if(diff == currentDiff && pixelFormat == capturer.preferredOutputPixelFormat()){
                selectedFormat = format
            }
        }
        
        return selectedFormat!
    }

    private func sendDataToRemote(_ data: Data) {
        if peerConnectionParameters.isDataChannelAvailable {
            sendCachedDataChannelDataToRemote()
            let buffer = RTCDataBuffer(data: data, isBinary: true)
            self.dataChannel?.sendData(buffer)
        } else {
            dataChannelLockQueue.sync {
                dataChannelQueue.enqueue(data)
            }
        }
    }
    
    private func sendCachedDataChannelDataToRemote() {
        while dataChannelQueue.elements.count > 0 {
            var element: Data?
            dataChannelLockQueue.sync {
                element = dataChannelQueue.dequeue() as? Data
            }
            if element != nil {
                let buffer = RTCDataBuffer(data: element!, isBinary: true)
                self.dataChannel?.sendData(buffer)
            }
        }
    }
    
    private func setQualityProfileForVideoSource() {
        let newProfile = CallsignalingProtocol.findCommonProfile(remoteProfile: self.remoteVideoQualityProfile, networkIsRelayed: networkIsRelayed)
        self.setOutgoingVideoLimits(maxBitrate: Int(newProfile.bitrate) * 1000, maxFps: Int(newProfile.maxFps), w: UInt32(newProfile.maxResolution.width), h: UInt32(newProfile.maxResolution.height))
        if let protobufMessage = CallsignalingProtocol.encodeVideoQuality(CallsignalingProtocol.localPeerQualityProfile().profile!) {
            self.sendDataToRemote(protobufMessage)
        }
    }
}

extension VoIPCallPeerConnectionClient {
    // MARK: Signaling
    func offer(completion: @escaping (_ sdp: RTCSessionDescription?, _ error: VoIPCallSdpPatcher.SdpError?) -> Void) {
        let constrains = VoIPCallPeerConnectionClient.mediaConstrains(isVideoCallAvailable: peerConnectionParameters.isVideoCallAvailable)
        self.peerConnection.offer(for: constrains) { (sdp, error) in
            guard let sdp = sdp else {
                return
            }
            
            let extensionConfig: VoIPCallSdpPatcher.RtpHeaderExtensionConfig = self.contact?.isVideoCallAvailable() ?? false ? .ENABLE_WITH_ONE_AND_TWO_BYTE_HEADER : .DISABLE
            do {
                let patchedSdpString = try VoIPCallSdpPatcher(extensionConfig).patch(type: .LOCAL_OFFER, sdp: sdp.sdp)
                let patchedSdp = RTCSessionDescription(type: sdp.type, sdp: patchedSdpString)
                self.peerConnection.setLocalDescription(patchedSdp, completionHandler: { (error) in
                    completion(patchedSdp, nil)
                })
            }
            catch let sdpError {
                completion(nil, sdpError as? VoIPCallSdpPatcher.SdpError)
            }
        }
    }
    
    func answer(completion: @escaping (_ sdp: RTCSessionDescription) -> Void)  {
        let constrains = VoIPCallPeerConnectionClient.mediaConstrains(isVideoCallAvailable: peerConnectionParameters.isVideoCallAvailable)
        self.peerConnection.answer(for: constrains) { (sdp, error) in
            guard let sdp = sdp else {
                return
            }
            
            self.peerConnection.setLocalDescription(sdp, completionHandler: { (error) in
                completion(sdp)
            })
        }
    }
    
    func set(remoteSdp: RTCSessionDescription, completion: @escaping (Error?) -> ()) {
        self.peerConnection.setRemoteDescription(remoteSdp, completionHandler: completion)
    }
    
    func set(addRemoteCandidate: RTCIceCandidate) {
        self.peerConnection.add(addRemoteCandidate) { (error) in
            if error != nil {
                DDLogNotice("VoipCallService: [cid=\(self.callId?.callId ?? 0)]: Can't add remote ICE candidate \(addRemoteCandidate.sdp)")
                return
            }
        }
    }
    
    func set(removeRemoteCandidates: [RTCIceCandidate]) {
        self.peerConnection.remove(removeRemoteCandidates)
    }
}

extension VoIPCallPeerConnectionClient: RTCPeerConnectionDelegate {
    // MARK: RTCPeerConnectionDelegates
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        DDLogNotice("VoipCallService: [cid=\(self.callId?.callId ?? 0)]: Signaling state change to \(stateChanged.debugDescription)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        DDLogNotice("VoipCallService: [cid=\(self.callId?.callId ?? 0)]: Did add stream")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        DDLogNotice("VoipCallService: [cid=\(self.callId?.callId ?? 0)]: Did remove stream")
    }

        
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        DDLogNotice("VoipCallService: [cid=\(self.callId?.callId ?? 0)]: Renegotiation needed")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        DDLogNotice("VoipCallService: [cid=\(self.callId?.callId ?? 0)]: ICE connection state change to \(newState.debugDescription)")
        
        if newState == .checking {
            // Schedule 'connecting' stats timer
            let options = VoIPStatsOptions.init()
            options.selectedCandidatePair = true
            options.transport = true
            options.crypto = true
            options.inboundRtp = true
            options.outboundRtp = true
            options.tracks = true
            options.candidatePairsFlag = .OVERVIEW_AND_DETAILED
            self.schedulePeriodStats(options: options, period: VoIPCallPeerConnectionClient.logStatsIntervalConnecting)
        }
        
        if VoIPCallStateManager.shared.currentCallState() == .initializing && (newState == .connected || newState == .completed) {
            let options = VoIPStatsOptions.init()
            options.selectedCandidatePair = true
            options.transport = true
            options.crypto = true
            options.inboundRtp = true
            options.outboundRtp = true
            options.tracks = true
            options.candidatePairsFlag = .OVERVIEW
            self.schedulePeriodStats(options: options, period: VoIPCallPeerConnectionClient.logStatsIntervalConnected)
            
            if peerConnectionParameters.isVideoCallAvailable {
                let receivedVideoOptions = VoIPStatsOptions.init()
                receivedVideoOptions.framesReceived = true
                receivedVideoOptions.selectedCandidatePair = true
                self.scheduleVideoStats(options: receivedVideoOptions, period: VoIPCallPeerConnectionClient.checkReceivingVideoInterval)
            }
        }
                        
        self.delegate?.peerConnectionClient(self, didChangeConnectionState: newState)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        DDLogNotice("VoipCallService: [cid=\(self.callId?.callId ?? 0)]: ICE gathering state change to \(newState.debugDescription)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        DDLogNotice("VoipCallService: [cid=\(self.callId?.callId ?? 0)]: New local ICE candidate: \(candidate.sdp)")
        self.delegate?.peerConnectionClient(self, addedCandidate: candidate)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        // Log is in the delegate
        self.delegate?.peerConnectionClient(self, removedCandidates: candidates)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        DDLogNotice("VoipCallService: [cid=\(self.callId?.callId ?? 0)]: New data channel: (\(dataChannel.label)) (id=\(dataChannel.channelId))")
    }
}

extension VoIPCallPeerConnectionClient: RTCDataChannelDelegate {
    // MARK: RTCDataChannelDelegate
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        peerConnectionParameters.isDataChannelAvailable = dataChannel.readyState == .open
        sendCachedDataChannelDataToRemote()
    }
    
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        self.delegate?.peerConnectionClient(self, didReceiveData: buffer.data)
    }
}

extension VoIPCallPeerConnectionClient {
    // MARK: VoIP Stats
    
    func schedulePeriodStats(options: VoIPStatsOptions, period: TimeInterval) {
        // check on main thread for statsTimer
        DispatchQueue.main.async {
            if self.statsTimer != nil {
                self.statsTimer?.invalidate()
                self.statsTimer = nil
            }
        }
        // Create new timer with <period> (but immediately log once)
        var dict = [AnyHashable: Any]()
        dict.updateValue(self.peerConnection, forKey: "connection")
        dict.updateValue(options, forKey: "options")
        self.logDebugStats(dict: dict)
        DispatchQueue.main.async {
            self.statsTimer = Timer.scheduledTimer(withTimeInterval: period, repeats: true, block: { (timer) in
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
        self.checkIsReceivingVideo(dict: dict)
        DispatchQueue.main.async {
            self.receivingVideoTimer = Timer.scheduledTimer(withTimeInterval: period, repeats: true, block: { (timer) in
                self.checkIsReceivingVideo(dict: dict)
            })
        }
    }
    
    func logDebugEndStats(completion: @escaping () -> ()) {
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
            let options = VoIPStatsOptions.init()
            options.selectedCandidatePair = false
            options.transport = true
            options.crypto = true
            options.inboundRtp = true
            options.outboundRtp = true
            options.tracks = true
            options.candidatePairsFlag = .OVERVIEW_AND_DETAILED
            
            // One-shot stats fetch before disconnect
            self.logDebugStats(dict: ["connection": peerConnection, "options": options, "callback": completion])
        } else {
            completion()
        }
    }
    
    func logDebugStats(dict: [AnyHashable: Any]) {
        let connection = dict["connection"] as! RTCPeerConnection
        let options = dict["options"] as! VoIPStatsOptions
                
        connection.statistics { (report) in
            let stats = VoIPStats.init(report: report, options: options, transceivers: connection.transceivers, previousState: self.previousPeriodDebugState)
            self.previousPeriodDebugState = stats.buildVoIPStatsState()
            self.networkIsRelayed = stats.usesRelay()

            var statsString = stats.getRepresentation()
            statsString += "\n\(CallsignalingProtocol.printDebugQualityProfiles(remoteProfile: self.remoteVideoQualityProfile, networkIsRelayed: self.networkIsRelayed))"
            DDLogNotice("VoipCallService: [cid=\(self.callId?.callId ?? 0)]: Stats: \n \(statsString)")
            
            // this is only needed if video calls are not available
            if !self.peerConnectionParameters.isVideoCallAvailable {
                self.checkIsSelectedCandidatePairCellular(stats: stats)
            }

            if let callback = dict["callback"] as?  (() -> Void) {
                callback()
            }
        }
    }
    
    func checkIsReceivingVideo(dict: [AnyHashable: Any]) {
        let connection = dict["connection"] as! RTCPeerConnection
        let options = dict["options"] as! VoIPStatsOptions
        
        connection.statistics { (report) in
            let stats = VoIPStats.init(report: report, options: options, transceivers: connection.transceivers, previousState: self.previousVideoState)
            self.previousVideoState = stats.buildVoIPStatsState()
            
            if !self.isRemoteVideoActivated {
                self.delegate?.peerConnectionClient(self, receivingVideo: stats.isReceivingVideo())
            }
            self.checkIsSelectedCandidatePairCellular(stats: stats)
        }
        if isRemoteVideoActivated {
            self.delegate?.peerConnectionClient(self, receivingVideo: true)
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
            let currentInternetStatus = internetReachability.currentReachabilityStatus()
            if lastInternetStatus != currentInternetStatus {
                lastInternetStatus = currentInternetStatus
                setQualityProfileForVideoSource()
            }
        }
    }
}
