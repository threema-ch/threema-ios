//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2020 Threema GmbH
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

@objc class VoIPCallStateManager: NSObject {
    
    @objc static let shared = VoIPCallStateManager()
    
    private var callQueue = Queue<Any>()
    private let lockQueue = DispatchQueue(label: "CallManagerLockQueue")
    private let managerQueue = DispatchQueue(label: "CallManagerProcessQueue")
    
    private var ringingTimer: Timer?
    private var callService =  VoIPCallService()
    
    @objc required override init() {
        super.init()
        callService.delegate = self
    }
    
    /**
     Get the current state of a call
     - Returns: CallState
     */
    @objc func currentCallState() -> VoIPCallService.CallState {
        return callService.currentState()
    }
    
    /**
     Get the current contact of a call
     - Returns: Contact
     */
    @objc func currentCallContact() -> Contact? {
        return callService.currentContact()
    }
    
    /**
    Get the current callId of a call
    - Returns: VoIPCallId
    */
    @objc func currentCallId() -> VoIPCallId? {
        return callService.currentCallId()
    }
    
    /**
     Is initiator of the current call
     - Returns: true or false
     */
    @objc func isCallInitiator() -> Bool {
        return callService.isCallInitiator()
    }
    
    /**
     Is the current call muted
     - Returns: true or false
     */
    @objc func isCallMuted() -> Bool {
        return callService.isCallMuted()
    }
    
    /**
     Is the speaker for the current call active
     - Returns: true or false
     */
    @objc func isSpeakerActive() -> Bool {
        return callService.isSpeakerActive()
    }
    
    /**
     Set the rtc audio session
     - parameter audioSession: audio session from callkit
     */
    @objc func setRTCAudio(_ audioSession: AVAudioSession) {
        callService.setRTCAudioSession(audioSession)
    }
    
    /**
     Set the audio session for RTC active
     - parameter audioSession: Set the audio session from callkit
     */
    @objc func activateRTCAudio() {
        callService.activateRTCAudio()
    }
    
    /**
     Is the current call already accepted
     - Returns: true or false
     */
    @objc func isCallAlreadyAccepted() -> Bool {
        return callService.isCallAlreadyAccepted()
    }
    
    /**
     Present the CallViewController
     */
    @objc func presentCallViewController() {
        callService.presentCallViewController()
    }
    
    /**
     Dismiss the CallViewController
     */
    @objc func dismissCallViewController() {
        callService.dismissCallViewController()
    }
    
    /**
     Start capture local video
     */
    @objc func startCaptureLocalVideo(renderer: RTCVideoRenderer, useBackCamera: Bool = false, switchCamera: Bool = false) {
        callService.startCaptureLocalVideo(renderer: renderer, useBackCamera: useBackCamera, switchCamera: switchCamera)
    }
    
    /**
     End capture local video
     */
    @objc func endCaptureLocalVideo(switchCamera: Bool = false) {
        callService.endCaptureLocalVideo(switchCamera: switchCamera)
    }
    
    /**
     Get local video
     */
    @objc func localVideoRenderer() -> RTCVideoRenderer? {
        return callService.localVideoRenderer()
    }
    
    /**
     Start render remote video
     */
    @objc func renderRemoteVideo(to renderer: RTCVideoRenderer) {
        callService.renderRemoteVideo(to: renderer)
    }
    
    /**
     End capture local video
     */
    @objc func endRemoteVideo() {
        callService.endRemoteVideo()
    }
    
    /**
     Get remote video
     */
    @objc func remoteVideoRenderer() -> RTCVideoRenderer? {
        return callService.remoteVideoRenderer()
    }
    
    /**
     Get peer video quality profile
     */
    func remoteVideoQualityProfile() -> CallsignalingProtocol.ThreemaVideoCallQualityProfile? {
        return callService.remoteVideoQualityProfile()
    }
    
    /**
     Get peer is using turn server
     */
     func networkIsRelayed() -> Bool {
        return callService.networkIsRelayed()
    }
        
    /**
     Add a user action to the process queue
     - parameter action: VoIPCallUserAction
     */
    @objc func processUserAction(_ action: VoIPCallUserAction) {
        addMessageToQueue(message: action)
    }

    /**
     Add a incoming call offer to the process queue
     - parameter offer: VoIPCallOfferMessage
     - parameter contact: Contact from the offer
     - parameter completion: Completion block
     */
    @objc func incomingCallOffer(offer: VoIPCallOfferMessage, contact theContact: Contact, completion: (() -> Void)?) {
        BackgroundTaskManager.shared.newBackgroundTask(key: kAppVoIPIncomCallBackgroundTask, timeout: Int(kAppVoIPIncomCallBackgroundTaskTime)) {
            if completion != nil {
                offer.completion = completion
            }
            offer.contact = theContact
            self.addMessageToQueue(message: offer)
        }
    }
    
    /**
     Add a incoming call answer to the process queue
     - parameter answer: VoIPCallAnswerMessage
     - parameter contact: Contact from the answer
     - parameter completion: Completion block
     */
    @objc func incomingCallAnswer(answer: VoIPCallAnswerMessage, contact theContact: Contact, completion: (() -> Void)?) {
        BackgroundTaskManager.shared.newBackgroundTask(key: kAppVoIPBackgroundTask, timeout: Int(kAppPushBackgroundTaskTime)) {
            if completion != nil {
                answer.completion = completion
            }
            answer.contact = theContact
            self.addMessageToQueue(message: answer)
        }
    }
    
    /**
     Add a incoming ringing message to the process queue
     - parameter ringing: VoIPCallRingingMessage
     */
    @objc func incomingCallRinging(ringing: VoIPCallRingingMessage) {
        BackgroundTaskManager.shared.newBackgroundTask(key: kAppVoIPBackgroundTask, timeout: Int(kAppPushBackgroundTaskTime)) {
            self.addMessageToQueue(message: ringing)
        }
    }
    
    /**
     Add a incoming hangup message to the process queue
     - parameter hangup: VoIPCallHangupMessage
     */
    @objc func incomingCallHangup(hangup: VoIPCallHangupMessage) {
        BackgroundTaskManager.shared.newBackgroundTask(key: kAppVoIPBackgroundTask, timeout: Int(kAppPushBackgroundTaskTime)) {
            self.addMessageToQueue(message: hangup)
        }
    }
    
    /**
     Add a incoming ice candidates message to the process queue
     - parameter candidates: VoIPCallIceCandidatesMessage
     - parameter contact: Contact from the ice candidates
     - parameter completion: Completion block
     */
    @objc func incomingIceCandidates(candidates: VoIPCallIceCandidatesMessage, contact theContact: Contact, completion: (() -> Void)?) {
        BackgroundTaskManager.shared.newBackgroundTask(key: kAppVoIPBackgroundTask, timeout: Int(kAppPushBackgroundTaskTime)) {
            if completion != nil {
                candidates.completion = completion
            }
            candidates.contact = theContact
            self.addMessageToQueue(message: candidates)
        }
    }
}

extension VoIPCallStateManager {
    // MARK: Private functions
    
    /**
     Add a message to the process queue and start process
     - parameter message: Any message
     */
    private func addMessageToQueue(message: Any) {
        var queueCountBefore = 0
        lockQueue.sync {
            DDLogNotice("Threema call: VoIPCallStateManager -> add message to queue \(message.self)");
            queueCountBefore = callQueue.elements.count
            callQueue.enqueue(message)
        }
        if queueCountBefore == 0 {
            processQueue()
        }
    }
    
    /**
     Start the process queue on CallService
     */
    private func processQueue() {
        var element: Any?
        lockQueue.sync {
            element = callQueue.dequeue()
        }
        if element != nil {
            managerQueue.async {
                DDLogNotice("Threema call: VoIPCallStateManager -> start process");
                self.callService.startProcess(element: element!)
            }
        }
    }
}

extension VoIPCallStateManager: VoIPCallServiceDelegate {
    /**
     Delegate from VoIPCallServiceDelegate
     Process next message if queue is not empty
     */
    func callServiceFinishedProcess() {
        DDLogNotice("Threema call: VoIPCallStateManager -> finished process, check next");
        if callQueue.elements.count > 0 {
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
        return elements.first
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

extension Queue: CustomStringConvertible {
    var description: String {
        return "\(elements)"
    }
}
