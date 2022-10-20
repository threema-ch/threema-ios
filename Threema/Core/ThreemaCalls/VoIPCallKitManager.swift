//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2022 Threema GmbH
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
import Foundation

protocol VoIPCallKitManagerDelegate: AnyObject {
    func callFailed()
}

final class VoIPCallKitManager: NSObject {
    
    private let provider: CXProvider
    private let callController: CXCallController
    private var uuid: UUID?
    private(set) var callerName: String?
    private var answerAction: CXAnswerCallAction?
    
    weak var delegate: VoIPCallKitManagerDelegate?
    
    override init() {
        self.provider = CXProvider(configuration: VoIPCallKitManager.providerConfiguration(for: nil))
        self.callController = CXCallController()
        super.init()
        provider.setDelegate(self, queue: nil)
    }
    
    class func providerConfiguration(for contactIdentity: String?) -> CXProviderConfiguration {
        let providerConfiguration = CXProviderConfiguration(localizedName: ThreemaApp.currentName)
        providerConfiguration.supportsVideo = true
        providerConfiguration.maximumCallGroups = 1
        providerConfiguration.maximumCallsPerCallGroup = 1
        providerConfiguration.supportedHandleTypes = [.generic]
        providerConfiguration.includesCallsInRecents = UserSettings.shared().includeCallsInRecents
        
        if let identity = contactIdentity {
            let pushSetting = PushSetting(forThreemaID: identity)
            if pushSetting.canSendPush(), pushSetting.silent == false {
                let voIPSound = UserSettings.shared()?.voIPSound
                if voIPSound != "default" {
                    providerConfiguration.ringtoneSound = "\(voIPSound!).caf"
                }
            }
            else {
                providerConfiguration.ringtoneSound = "silent.mp3"
            }
        }
        
        let image = BundleUtil.imageNamed("VoipThreema")
        providerConfiguration.iconTemplateImageData = image?.pngData()
        return providerConfiguration
    }
}

extension VoIPCallKitManager {
    // MARK: Public functions
    
    /// Get current UUID of call
    /// - Returns: UUID
    func currentUUID() -> UUID? {
        uuid
    }
    
    func reportIncomingCall(uuid: UUID, contactIdentity: String) {
        self.uuid = uuid
        callerName = contactIdentity
        provider.configuration = VoIPCallKitManager.providerConfiguration(for: contactIdentity)
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: contactIdentity)
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsHolding = false
        update.supportsDTMF = false
        update.hasVideo = false
        let entityManager = BusinessInjector().entityManager
        entityManager.performBlockAndWait {
            if let contact = entityManager.entityFetcher.contact(for: contactIdentity) {
                update.localizedCallerName = contact.displayName
                self.callerName = contact.displayName
            }
        }
        
        RTCAudioSession.sharedInstance().useManualAudio = true
        VoIPCallKitManager.configureAudioSession()
        
        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            if error != nil {
                self.delegate?.callFailed()
            }
        }
    }
    
    func updateReportedIncomingCall(uuid: UUID, contactIdentity: String) {
        provider.configuration = VoIPCallKitManager.providerConfiguration(for: contactIdentity)
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: contactIdentity)
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsHolding = false
        update.supportsDTMF = false
        update.hasVideo = false
        if let contact = BusinessInjector().entityManager.entityFetcher.contact(for: contactIdentity) {
            update.localizedCallerName = contact.displayName
            callerName = contact.displayName
        }
        else {
            callerName = contactIdentity
        }
        
        RTCAudioSession.sharedInstance().useManualAudio = true
        VoIPCallKitManager.configureAudioSession()

        provider.reportCall(with: uuid, updated: update)
    }
    
    func startCall(for contactIdentity: String) {
        let handle = CXHandle(type: .generic, value: contactIdentity)
        uuid = UUID()
        callerName = contactIdentity
        
        let startCallAction = CXStartCallAction(call: uuid!, handle: handle)
        let transaction = CXTransaction(action: startCallAction)
        callController.request(transaction, completion: { error in
            if error != nil {
                self.delegate?.callFailed()
            }
            let update = CXCallUpdate()
            update.remoteHandle = CXHandle(type: .generic, value: contactIdentity)
            update.hasVideo = false
            let entityManager = BusinessInjector().entityManager
            entityManager.performBlockAndWait {
                if let contact = entityManager.entityFetcher.contact(for: contactIdentity) {
                    update.localizedCallerName = contact.displayName
                    self.callerName = contact.displayName
                }
            }
            self.provider.reportCall(with: self.uuid!, updated: update)
        })
    }
    
    func callAccepted() {
        if let callID = uuid {
            provider.reportOutgoingCall(with: callID, startedConnectingAt: Date())
        }
    }
    
    func callConnected() {
        if let callID = uuid {
            provider.reportOutgoingCall(with: callID, connectedAt: Date())
            answerAction?.fulfill()
        }
    }
    
    func answerFailed() {
        answerAction?.fail()
        uuid = nil
        callerName = nil
    }
    
    func endCall() {
        if let callID = uuid {
            let action = CXEndCallAction(call: callID)
            let transaction = CXTransaction(action: action)
            callController.request(transaction, completion: { _ in
                // do noting
            })
        }
        uuid = nil
        callerName = nil
    }
    
    func timeoutCall() {
        if let id = uuid {
            let action = CXEndCallAction(call: id)
            let transaction = CXTransaction(action: action)
            callController.request(transaction, completion: { _ in
                // do noting
            })
        }
        uuid = nil
        callerName = nil
    }

    func rejectCall() {
        if let id = uuid {
            let action = CXEndCallAction(call: id)
            let transaction = CXTransaction(action: action)
            callController.request(transaction, completion: { _ in
                // do noting
            })
        }
        uuid = nil
        callerName = nil
    }
    
    static func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [.allowBluetooth, .allowBluetoothA2DP]
            )
            try audioSession.setActive(true)
        }
        catch {
            print(error.localizedDescription)
        }
    }
}

// MARK: - CXProviderDelegate

extension VoIPCallKitManager: CXProviderDelegate {
    // MARK: CXProviderDelegate

    func providerDidReset(_ provider: CXProvider) {
        let state = VoIPCallStateManager.shared.currentCallState()
        if state == .incomingRinging || state == .calling || state == .reconnecting {
            if let contactIdentity = VoIPCallStateManager.shared.currentCallIdentity() {
                if let currentCallID = VoIPCallStateManager.shared.currentCallID() {
                    BackgroundTaskManager.shared.newBackgroundTask(
                        key: kAppVoIPBackgroundTask,
                        timeout: Int(kAppVoIPBackgroundTaskTime)
                    ) {
                        ServerConnector.shared()?.connectWait(initiator: .threemaCall)
                        var userAction: VoIPCallUserAction?
                        if VoIPCallStateManager.shared.currentCallState() == .incomingRinging {
                            userAction = VoIPCallUserAction(
                                action: .reject,
                                contactIdentity: contactIdentity,
                                callID: currentCallID,
                                completion: nil
                            )
                        }
                        else {
                            userAction = VoIPCallUserAction(
                                action: .end,
                                contactIdentity: contactIdentity,
                                callID: currentCallID,
                                completion: nil
                            )
                        }
                        VoIPCallStateManager.shared.processUserAction(userAction!)
                    }
                }
            }
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        if let contactIdentity = VoIPCallStateManager.shared.currentCallIdentity() {
            if let currentCallID = VoIPCallStateManager.shared.currentCallID() {
                BackgroundTaskManager.shared.newBackgroundTask(
                    key: kAppVoIPBackgroundTask,
                    timeout: Int(kAppPushBackgroundTaskTime)
                ) {
                    ServerConnector.shared()?.connectWait(initiator: .threemaCall)
                    self.answerAction = action
                    VoIPCallKitManager.configureAudioSession()
                    let action = VoIPCallUserAction(
                        action: .acceptCallKit,
                        contactIdentity: contactIdentity,
                        callID: currentCallID,
                        completion: nil
                    )
                    VoIPCallStateManager.shared.processUserAction(action)
                }
            }
        }
        else {
            action.fail()
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        guard let contactIdentity = VoIPCallStateManager.shared.currentCallIdentity(),
              let callID = VoIPCallStateManager.shared.currentCallID() else {
            action.fulfill()
            return
        }
        
        let state = VoIPCallStateManager.shared.currentCallState()
        switch state {
        case .ended, .remoteEnded, .rejected, .rejectedBusy, .rejectedTimeout, .rejectedDisabled, .rejectedOffHours,
             .rejectedUnknown, .microphoneDisabled:
            action.fulfill()
            return
        case .idle, .sendOffer, .receivedOffer, .outgoingRinging, .incomingRinging, .sendAnswer, .receivedAnswer,
             .initializing, .calling, .reconnecting:
            // do nothing
            break
        }
                
        BackgroundTaskManager.shared.newBackgroundTask(
            key: kAppVoIPBackgroundTask,
            timeout: Int(kAppPushBackgroundTaskTime)
        ) {
            ServerConnector.shared()?.connectWait(initiator: .threemaCall)
            var userAction: VoIPCallUserAction?
            if VoIPCallStateManager.shared.currentCallState() == .incomingRinging {
                userAction = VoIPCallUserAction(
                    action: .reject,
                    contactIdentity: contactIdentity,
                    callID: callID,
                    completion: {
                        action.fulfill()
                    }
                )
            }
            else {
                userAction = VoIPCallUserAction(
                    action: .end,
                    contactIdentity: contactIdentity,
                    callID: callID,
                    completion: {
                        action.fulfill()
                    }
                )
            }
            VoIPCallStateManager.shared.processUserAction(userAction!)
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        guard let contactIdentity = VoIPCallStateManager.shared.currentCallIdentity(),
              let callID = VoIPCallStateManager.shared.currentCallID() else {
            action.fail()
            return
        }
        
        BackgroundTaskManager.shared.newBackgroundTask(
            key: kAppVoIPBackgroundTask,
            timeout: Int(kAppVoIPBackgroundTaskTime)
        ) {
            ServerConnector.shared()?.connectWait(initiator: .threemaCall)
            let actionType: VoIPCallUserAction.Action = action.isMuted ? .muteAudio : .unmuteAudio
            let userAction = VoIPCallUserAction(
                action: actionType,
                contactIdentity: contactIdentity,
                callID: callID,
                completion: {
                    action.fulfill()
                }
            )
            VoIPCallStateManager.shared.processUserAction(userAction)
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        guard let contactIdentity = VoIPCallStateManager.shared.currentCallIdentity(),
              let callID = VoIPCallStateManager.shared.currentCallID() else {
            action.fail()
            return
        }
        
        BackgroundTaskManager.shared.newBackgroundTask(
            key: kAppVoIPBackgroundTask,
            timeout: Int(kAppVoIPBackgroundTaskTime)
        ) {
            ServerConnector.shared()?.connectWait(initiator: .threemaCall)
            let actionType: VoIPCallUserAction.Action = action.isOnHold ? .muteAudio : .unmuteAudio
            let action = VoIPCallUserAction(
                action: actionType,
                contactIdentity: contactIdentity,
                callID: callID,
                completion: {
                    action.fulfill()
                }
            )
            VoIPCallStateManager.shared.processUserAction(action)
        }
    }
    
    func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        guard let contactIdentity = VoIPCallStateManager.shared.currentCallIdentity(),
              let callID = VoIPCallStateManager.shared.currentCallID() else {
            action.fulfill()
            return
        }
        
        BackgroundTaskManager.shared.newBackgroundTask(
            key: kAppVoIPBackgroundTask,
            timeout: Int(kAppVoIPBackgroundTaskTime)
        ) {
            ServerConnector.shared()?.connectWait(initiator: .threemaCall)
            
            switch VoIPCallStateManager.shared.currentCallState() {
            case .idle, .ended, .remoteEnded, .rejected, .rejectedBusy, .rejectedTimeout, .rejectedOffHours,
                 .rejectedUnknown, .rejectedDisabled, .microphoneDisabled:
                action.fulfill()
            case .sendOffer, .outgoingRinging, .sendAnswer, .receivedAnswer, .initializing, .calling, .reconnecting:
                let userAction = VoIPCallUserAction(
                    action: .end,
                    contactIdentity: contactIdentity,
                    callID: callID,
                    completion: {
                        action.fulfill()
                    }
                )
                VoIPCallStateManager.shared.processUserAction(userAction)
            case .receivedOffer, .incomingRinging:
                let userAction = VoIPCallUserAction(
                    action: .rejectUnknown,
                    contactIdentity: contactIdentity,
                    callID: callID,
                    completion: {
                        action.fulfill()
                    }
                )
                VoIPCallStateManager.shared.processUserAction(userAction)
            }
        }
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        VoIPCallStateManager.shared.setRTCAudio(audioSession)
    }
}
