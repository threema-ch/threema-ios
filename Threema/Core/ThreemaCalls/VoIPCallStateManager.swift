//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2023 Threema GmbH
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

import CallKit
import CocoaLumberjackSwift
import Foundation
import ThreemaFramework
import UserNotifications

@objc class VoIPCallStateManager: NSObject {
    
    @objc static let shared = VoIPCallStateManager()
    
    private var callQueue = Queue<Any>()
    private let lockQueue = DispatchQueue(label: "CallManagerLockQueue")
    private let managerQueue = DispatchQueue(label: "CallManagerProcessQueue")
    
    private var callService = VoIPCallService()
    
    private let preCallHandlingTimeout = 5
    
    @objc override required init() {
        super.init()
        callService.delegate = self
    }
    
    /// Indicates that we have started handling a call but have not yet processed any message related to any call
    @objc public var preCallHandling = false {
        didSet {
            if preCallHandling {
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(preCallHandlingTimeout)) {
                    if self.preCallHandling {
                        DDLogError(
                            "preCallHandling is taking longer than five seconds! Current state is \(self.callService.currentState()) callID \(String(describing: self.callService.currentCallID()))"
                        )
                    }
                }
            }
        }
    }
    
    /// Get the current state of a call
    /// - Returns: CallState
    @objc func currentCallState() -> VoIPCallService.CallState {
        callService.currentState()
    }
    
    /// Get the current identity of a call
    /// - Returns: identity
    @objc func currentCallIdentity() -> String? {
        callService.currentContactIdentity()
    }
    
    /// Get the current callID of a call
    /// - Returns: VoIPCallID
    @objc func currentCallID() -> VoIPCallID? {
        callService.currentCallID()
    }
    
    /// Is initiator of the current call
    /// - Returns: true or false
    @objc func isCallInitiator() -> Bool {
        callService.isCallInitiator()
    }
    
    /// Is the current call muted
    /// - Returns: true or false
    @objc func isCallMuted() -> Bool {
        callService.isCallMuted()
    }
    
    /// Is the speaker for the current call active
    /// - Returns: true or false
    @objc func isSpeakerActive() -> Bool {
        callService.isSpeakerActive()
    }
    
    /// Set the rtc audio session
    /// - parameter audioSession: audio session from callkit
    @objc func setRTCAudio(_ audioSession: AVAudioSession) {
        callService.setRTCAudioSession(audioSession)
    }
    
    /// Set the audio session for RTC active
    /// - parameter audioSession: Set the audio session from callkit
    @objc func activateRTCAudio() {
        callService.activateRTCAudio()
    }
    
    /// Is the current call already accepted
    /// - Returns: true or false
    @objc func isCallAlreadyAccepted() -> Bool {
        callService.isCallAlreadyAccepted()
    }
    
    /// Present the CallViewController
    @objc func presentCallViewController() {
        callService.presentCallViewController()
    }
    
    /// Dismiss the CallViewController
    @objc func dismissCallViewController() {
        callService.dismissCallViewController()
    }
    
    /// Start capture local video
    @objc func startCaptureLocalVideo(
        renderer: RTCVideoRenderer,
        useBackCamera: Bool = false,
        switchCamera: Bool = false
    ) {
        callService.startCaptureLocalVideo(renderer: renderer, useBackCamera: useBackCamera, switchCamera: switchCamera)
    }
    
    /// End capture local video
    @objc func endCaptureLocalVideo(switchCamera: Bool = false) {
        callService.endCaptureLocalVideo(switchCamera: switchCamera)
    }
    
    /// Get local video
    @objc func localVideoRenderer() -> RTCVideoRenderer? {
        callService.localVideoRenderer()
    }
    
    /// Start render remote video
    @objc func renderRemoteVideo(to renderer: RTCVideoRenderer) {
        callService.renderRemoteVideo(to: renderer)
    }
    
    /// End capture local video
    @objc func endRemoteVideo() {
        callService.endRemoteVideo()
    }
    
    /// Get remote video
    @objc func remoteVideoRenderer() -> RTCVideoRenderer? {
        callService.remoteVideoRenderer()
    }
    
    /// Get peer video quality profile
    func remoteVideoQualityProfile() -> CallsignalingProtocol.ThreemaVideoCallQualityProfile? {
        callService.remoteVideoQualityProfile()
    }
    
    /// Get peer is using turn server
    func networkIsRelayed() -> Bool {
        callService.networkIsRelayed()
    }
        
    /// Add a user action to the process queue
    /// - parameter action: VoIPCallUserAction
    @objc func processUserAction(_ action: VoIPCallUserAction) {
        addMessageToQueue(message: action)
    }

    /// Add a incoming call offer to the process queue
    /// - parameter offer: VoIPCallOfferMessage
    /// - parameter identity: Identity from the offer
    /// - parameter completion: Completion block
    @objc func incomingCallOffer(offer: VoIPCallOfferMessage, identity theIdentity: String, completion: (() -> Void)?) {
        BackgroundTaskManager.shared.newBackgroundTask(
            key: kAppVoIPIncomCallBackgroundTask,
            timeout: Int(kAppVoIPIncomCallBackgroundTaskTime)
        ) {
            if completion != nil {
                offer.completion = completion
            }
            offer.contactIdentity = theIdentity
            self.addMessageToQueue(message: offer)
        }
    }
    
    /// Add a incoming call answer to the process queue
    /// - parameter answer: VoIPCallAnswerMessage
    /// - parameter identity: Identity from the answer
    /// - parameter completion: Completion block
    @objc func incomingCallAnswer(
        answer: VoIPCallAnswerMessage,
        identity theIdentity: String,
        completion: (() -> Void)?
    ) {
        BackgroundTaskManager.shared.newBackgroundTask(
            key: kAppVoIPBackgroundTask,
            timeout: Int(kAppPushBackgroundTaskTime)
        ) {
            if completion != nil {
                answer.completion = completion
            }
            answer.contactIdentity = theIdentity
            self.addMessageToQueue(message: answer)
        }
    }
    
    /// Starts an incoming call when app is in background
    @objc func startInitialIncomingCall(
        dictionaryPayload: [AnyHashable: Any],
        completion: @escaping () -> Void
    ) -> Bool {
        
        // VoIP notification from Threema Web
        // Other invalid VoIP push payloads
        guard dictionaryPayload["3mw"] == nil,
              let callerIdentity = dictionaryPayload["NotificationExtensionOffer"] as? String else {
            DDLogError("Received invalid push payload with dictionary \(dictionaryPayload)")
            startAndCancelCall(
                from: BundleUtil.localizedString(forKey: ThreemaApp.currentName),
                completion: completion,
                showWebNotification: true
            )
            return false
        }
        
        // Due to changes in the iOS 15 SDK, the app crashed because we took too long to report an incoming call to call kit when the app was in background. Therefore we start an initial call which then gets updated later, when the offer message is received from the server.
        // This must not fail to report a call.
        callService.reportInitialCall(
            from: callerIdentity,
            name: dictionaryPayload["NotificationExtensionCallerName"] as? String
        )
        return true
    }
    
    @objc public func startAndCancelCall(
        from localizedName: String,
        completion: @escaping () -> Void,
        showWebNotification: Bool
    ) {
        let callUpdate = CXCallUpdate()
        callUpdate.remoteHandle = CXHandle(type: .generic, value: localizedName)
        callUpdate.supportsDTMF = false
        callUpdate.supportsHolding = false
        callUpdate.supportsGrouping = false
        callUpdate.supportsUngrouping = false
        callUpdate.hasVideo = false
        
        let config = CXProviderConfiguration(localizedName: localizedName)
        config.supportsVideo = true
        config.maximumCallGroups = 1
        config.maximumCallsPerCallGroup = 1
        config.includesCallsInRecents = false

        let uuid = UUID()
        
        let provider = CXProvider(configuration: config)
        provider.reportNewIncomingCall(with: uuid, update: callUpdate, completion: { _ in
            DispatchQueue.main.async {
                if showWebNotification {
                    let title = BundleUtil.localizedString(forKey: "webClientSession_error_voip_title")
                    let localizedMessage = String.localizedStringWithFormat(
                        BundleUtil.localizedString(forKey: "webClientSession_error_voip_message"),
                        ThreemaApp.currentName
                    )

                    NotificationManager.showThreemaWebError(title: title, body: localizedMessage)
                }
                else {
                    let localizedMessage = BundleUtil.localizedString(forKey: "new_message_db_requires_migration")
                    NotificationManager.showThreemaWebError(title: ThreemaApp.currentName, body: localizedMessage)
                }
            }
            
            provider.reportCall(with: uuid, endedAt: Date(), reason: .failed)
            completion()
        })
        provider.reportCall(with: uuid, endedAt: Date(), reason: .failed)
    }
    
    /// Add a incoming ringing message to the process queue
    /// - parameter ringing: VoIPCallRingingMessage
    @objc func incomingCallRinging(ringing: VoIPCallRingingMessage) {
        BackgroundTaskManager.shared.newBackgroundTask(
            key: kAppVoIPBackgroundTask,
            timeout: Int(kAppPushBackgroundTaskTime)
        ) {
            self.addMessageToQueue(message: ringing)
        }
    }
    
    /// Add a incoming hangup message to the process queue
    /// - parameter hangup: VoIPCallHangupMessage
    @objc func incomingCallHangup(hangup: VoIPCallHangupMessage) {
        BackgroundTaskManager.shared.newBackgroundTask(
            key: kAppVoIPBackgroundTask,
            timeout: Int(kAppPushBackgroundTaskTime)
        ) {
            self.addMessageToQueue(message: hangup)
        }
    }
    
    /// Add a incoming ice candidates message to the process queue
    /// - parameter candidates: VoIPCallIceCandidatesMessage
    /// - parameter identity: Identity from the ice candidates
    /// - parameter completion: Completion block
    @objc func incomingIceCandidates(
        candidates: VoIPCallIceCandidatesMessage,
        identity theIdentity: String,
        completion: (() -> Void)?
    ) {
        BackgroundTaskManager.shared.newBackgroundTask(
            key: kAppVoIPBackgroundTask,
            timeout: Int(kAppPushBackgroundTaskTime)
        ) {
            if completion != nil {
                candidates.completion = completion
            }
            candidates.contactIdentity = theIdentity
            self.addMessageToQueue(message: candidates)
        }
    }
}

extension VoIPCallStateManager {
    // MARK: Private functions
    
    /// Add a message to the process queue and start process
    /// - parameter message: Any message
    private func addMessageToQueue(message: Any) {
        var queueCountBefore = 0
        lockQueue.sync {
            queueCountBefore = callQueue.elements.count
            callQueue.enqueue(message)
        }
        if queueCountBefore == 0 {
            processQueue()
        }
    }
    
    /// Start the process queue on CallService
    private func processQueue() {
        var element: Any?
        lockQueue.sync {
            element = callQueue.dequeue()
        }
        if let element {
            managerQueue.async {
                self.callService.startProcess(element: element)
            }
        }
    }
}

// MARK: - VoIPCallServiceDelegate

extension VoIPCallStateManager: VoIPCallServiceDelegate {
    /// Delegate from VoIPCallServiceDelegate
    /// Process next message if queue is not empty
    func callServiceFinishedProcess() {
        defer {
            preCallHandling = false
        }
        
        if !callQueue.elements.isEmpty {
            processQueue()
        }
    }
}

protocol Enqueuable {
    associatedtype Element
    mutating func enqueue(_ element: Element)
    func peek() -> Element?
    mutating func dequeue() -> Element?
    mutating func removeAll()
}

struct Queue<T>: Enqueuable {
    typealias Element = T
    
    internal var elements = [Element]()
    
    internal mutating func enqueue(_ element: Element) {
        elements.append(element)
    }
    
    internal func peek() -> Element? {
        elements.first
    }
    
    internal mutating func dequeue() -> Element? {
        guard elements.isEmpty == false else {
            return nil
        }
        return elements.removeFirst()
    }
    
    internal mutating func removeAll() {
        elements.removeAll()
    }
}

// MARK: - CustomStringConvertible

extension Queue: CustomStringConvertible {
    var description: String {
        "\(elements)"
    }
}
