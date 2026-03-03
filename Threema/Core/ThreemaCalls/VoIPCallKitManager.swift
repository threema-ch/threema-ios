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

import CallKit
import CocoaLumberjackSwift
import Foundation
import ThreemaEssentials

final class VoIPCallKitManager: NSObject {
    /// Current UUID of call
    public private(set) var uuid: UUID?
    private var callID: VoIPCallID?
    
    private let provider: CXProvider
    private let callController: CXCallController
    private(set) var callerName: String?
    private var answerAction: CXAnswerCallAction?
    
    /// The call will be set to true if a call fails, ends, or is rejected by the application. If CallKit triggers one
    /// of these actions, we will have a loop to wait until all information is loaded. This value will bypass the loop
    /// to close CallKit directly.
    private var dismissCallKitDirectly = false

    override init() {
        self.provider = CXProvider(configuration: VoIPCallKitManager.providerConfiguration())
        self.callController = CXCallController()
        super.init()
        provider.setDelegate(self, queue: nil)
    }
    
    class func providerConfiguration(ringtoneSound: String? = "default") -> CXProviderConfiguration {
        let providerConfiguration = CXProviderConfiguration()
        providerConfiguration.supportsVideo = true
        providerConfiguration.maximumCallGroups = 1
        providerConfiguration.maximumCallsPerCallGroup = 1
        providerConfiguration.supportedHandleTypes = [.generic]
        providerConfiguration.includesCallsInRecents = UserSettings.shared().includeCallsInRecents
        providerConfiguration.ringtoneSound = ringtoneSound
        providerConfiguration.iconTemplateImageData = Colors.callKitLogo.pngData()
        return providerConfiguration
    }
}

extension VoIPCallKitManager {
    // MARK: Public functions
    
    /// Report new incoming call to CallKit.
    /// - Parameters:
    ///   - uuid: CallKit UUID
    ///   - callID: ID of the call
    ///   - contactIdentity: Caller identity
    ///   - displayName: Display Name of caller
    ///   - ringtoneSound: Filename of ringtone to be used
    ///   - completion: Completion handler returns true if call successfully reported to CallKit
    func reportIncomingCall(
        uuid: UUID,
        callID: VoIPCallID,
        contactIdentity: String,
        displayName: String?,
        ringtoneSound: String,
        completion: @escaping (Bool) -> Void
    ) {
        self.uuid = uuid
        self.callID = callID
        
        callerName = displayName ?? contactIdentity
        provider.configuration = VoIPCallKitManager.providerConfiguration(ringtoneSound: ringtoneSound)
       
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: contactIdentity)
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsHolding = false
        update.supportsDTMF = false
        update.hasVideo = false
        let entityManager = BusinessInjector.ui.entityManager
        entityManager.performAndWait {
            if let contact = entityManager.entityFetcher.contactEntity(for: contactIdentity) {
                update.localizedCallerName = contact.displayName
                self.callerName = contact.displayName
            }
        }
        
        RTCAudioSession.sharedInstance().useManualAudio = true
        
        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error {
                DDLogError(
                    "CallKitManager: [cid=\(callID.callID)]: Report new incoming call failed (CallKit UUID: \(uuid): \(error)"
                )
                completion(false)
            }
            else {
                completion(true)
            }
        }
    }
    
    /// Report new incoming from the NSE call to CallKit.
    /// - Parameters:
    ///   - uuid: CallKit UUID
    ///   - callID: ID of the call
    ///   - contactIdentity: Caller identity
    ///   - contactName: Caller name
    ///   - ringtoneSound: Filename of ringtone to be used
    ///   - completion: Completion handler returns error
    func reportIncomingCallFromBackground(
        uuid: UUID,
        callID: VoIPCallID,
        contactIdentity: String,
        contactName: String?,
        ringtoneSound: String,
        completion: @escaping (Error?) -> Void
    ) {
        self.uuid = uuid
        self.callID = callID
        
        callerName = contactName ?? contactIdentity
        provider.configuration = VoIPCallKitManager.providerConfiguration(ringtoneSound: ringtoneSound)
        
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: contactIdentity)
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsHolding = false
        update.supportsDTMF = false
        update.hasVideo = false

        RTCAudioSession.sharedInstance().useManualAudio = true
       
        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error {
                DDLogError(
                    "CallKitManager: [cid=\(callID.callID)]: Report new incoming call from background failed (CallKit UUID: \(uuid): \(error)"
                )
            }
            completion(error)
        }
    }
    
    func updateReportedIncomingCall(uuid: UUID, contactIdentity: String, ringtoneSound: String) {
        provider.configuration = VoIPCallKitManager.providerConfiguration(ringtoneSound: ringtoneSound)
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: contactIdentity)
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsHolding = false
        update.supportsDTMF = false
        update.hasVideo = false
       
        let entityManager = BusinessInjector.ui.entityManager
        entityManager.performAndWait {
            if let contact = entityManager.entityFetcher.contactEntity(for: contactIdentity) {
                update.localizedCallerName = contact.displayName
                self.callerName = contact.displayName
            }
            else {
                self.callerName = contactIdentity
            }
        }
        
        RTCAudioSession.sharedInstance().useManualAudio = true

        provider.reportCall(with: uuid, updated: update)
    }
    
    func startCall(for contactIdentity: String) {
        let handle = CXHandle(type: .generic, value: contactIdentity)
        let localUUID = UUID()
        uuid = localUUID
        callerName = contactIdentity
        
        let startCallAction = CXStartCallAction(call: localUUID, handle: handle)
        let transaction = CXTransaction(action: startCallAction)
        callController.request(transaction) { error in
            
            if let error {
                DDLogError(
                    "CallKitManager: [cid=\(self.callID?.callID ?? "unknown")]: Start call action failed (CallKit UUID: \(localUUID): \(error)"
                )
                return
            }
            
            guard let uuid = self.uuid, localUUID == uuid else {
                DDLogError(
                    "CallKitManager: [cid=\(self.callID?.callID ?? "unknown")]: UUID mismatch local=\(localUUID), class=\(self.uuid ?? "nil")"
                )
                return
            }
            
            let update = CXCallUpdate()
            update.remoteHandle = CXHandle(type: .generic, value: contactIdentity)
            update.hasVideo = false
            
            let entityManager = BusinessInjector.ui.entityManager
            entityManager.performAndWait {
                if let contact = entityManager.entityFetcher.contactEntity(for: contactIdentity) {
                    update.localizedCallerName = contact.displayName
                    self.callerName = contact.displayName
                }
            }
            self.provider.reportCall(with: localUUID, updated: update)
        }
    }
    
    func callAccepted() {
        guard let callID = uuid else {
            return
        }
        
        provider.reportOutgoingCall(with: callID, startedConnectingAt: Date())
    }
    
    func callConnected() {
        guard let callID = uuid else {
            return
        }
        
        provider.reportOutgoingCall(with: callID, connectedAt: Date())
        answerAction?.fulfill()
    }
    
    func answerFailed() {
        answerAction?.fail()
        uuid = nil
        callerName = nil
    }
    
    func endCall() {
        if let uuid {
            dismissCallKitDirectly = true
            let action = CXEndCallAction(call: uuid)
            let transaction = CXTransaction(action: action)
            callController.request(transaction) { error in
                if let error {
                    DDLogError(
                        "CallKitManager: [cid=\(self.callID?.callID ?? "unknown")]: End call action failed (CallKit UUID: \(uuid): \(error)"
                    )
                }
            }
        }
        
        uuid = nil
        callerName = nil
    }
    
    func timeoutCall() {
        if let uuid {
            let action = CXEndCallAction(call: uuid)
            let transaction = CXTransaction(action: action)
            callController.request(transaction) { error in
                if let error {
                    DDLogError(
                        "CallKitManager: [cid=\(self.callID?.callID ?? "unknown")]: Timeout call action failed (CallKit UUID: \(uuid): \(error)"
                    )
                }
            }
        }
        
        uuid = nil
        callerName = nil
    }

    func rejectCall() {
        if let uuid {
            dismissCallKitDirectly = true
            let action = CXEndCallAction(call: uuid)
            let transaction = CXTransaction(action: action)
            callController.request(transaction) { error in
                if let error {
                    DDLogError(
                        "CallKitManager: [cid=\(self.callID?.callID ?? "unknown")]: Reject call action failed (CallKit UUID: \(uuid): \(error)"
                    )
                }
            }
        }
        
        uuid = nil
        callerName = nil
    }
}

// MARK: - CXProviderDelegate

extension VoIPCallKitManager: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        DDLogNotice(
            "CallKitManager: [cid=\(callID?.callID != nil ? String(callID!.callID) : "unknown")]: Provider did reset"
        )
        
        guard let contactIdentity = VoIPCallStateManager.shared.currentContactIdentity(),
              let currentCallID = VoIPCallStateManager.shared.currentCallID() else {
            DDLogError(
                "CallKitManager: [cid=\(callID?.callID ?? "unknown")]: Did not handle provider reset due to missing call state"
            )
            return
        }
        
        let state = VoIPCallStateManager.shared.currentCallState()
        guard state == .incomingRinging || state == .calling || state == .reconnecting else {
            DDLogError(
                "CallKitManager: [cid=\(callID?.callID ?? "unknown")]: Did not handle provider reset due to being in wrong call state: \(state.rawValue)"
            )
            return
        }
        
        BackgroundTaskManager.shared.newBackgroundTask(
            key: kAppVoIPBackgroundTask,
            timeout: Int(kAppVoIPBackgroundTaskTime)
        ) {
            ServerConnector.shared().connectWait(initiator: .threemaCall)
            let userAction =
                if VoIPCallStateManager.shared.currentCallState() == .incomingRinging {
                    VoIPCallUserAction(
                        action: .reject,
                        contactIdentity: contactIdentity,
                        callID: currentCallID,
                        completion: nil
                    )
                }
                else {
                    VoIPCallUserAction(
                        action: .end,
                        contactIdentity: contactIdentity,
                        callID: currentCallID,
                        completion: nil
                    )
                }
                    
            VoIPCallStateManager.shared.processUserAction(userAction)
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        DDLogNotice(
            "CallKitManager: [cid=\(callID?.callID != nil ? String(callID!.callID) : "unknown")]: Start call action"
        )

        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        Task {
            DDLogNotice(
                "CallKitManager: [cid=\(self.callID?.callID != nil ? String(self.callID!.callID) : "unknown")]: Answer call action"
            )
            
            // Since we have a suspension point during the launch of the app, but we need to report the call to call kit
            // directly, there might be the case that the user answers the call, before all needed information is
            // available. We there fore wait here for the info to be filled.
            var totalWait = 0.0
            let waitDuration = 0.1
            let maxWaitDuration = 10.0
            
            while VoIPCallStateManager.shared.currentContactIdentity() == nil || VoIPCallStateManager.shared
                .currentCallID() == nil {
                DDLogNotice(
                    "CallKitManager: [cid=\(String(describing: self.callID?.callID))]: Waiting for call info, total wait time: \(totalWait)s"
                )
                
                try? await Task.sleep(seconds: waitDuration)
                totalWait += waitDuration
                
                if totalWait > maxWaitDuration {
                    DDLogError(
                        "CallKitManager: [cid=\(self.callID?.callID ?? "unknown")]: Timeout waiting for call info. Failing call."
                    )
                    action.fail()
                    return
                }
            }
            
            guard let contactIdentity = VoIPCallStateManager.shared.currentContactIdentity(),
                  let callID = VoIPCallStateManager.shared.currentCallID() else {
                DDLogError(
                    "CallKitManager: [cid=\(self.callID?.callID ?? "unknown")]: Fail start call action due to missing call state"
                )
                action.fail()
                return
            }
            
            BackgroundTaskManager.shared.newBackgroundTask(
                key: kAppVoIPBackgroundTask,
                timeout: Int(kAppPushBackgroundTaskTime)
            ) {
                ServerConnector.shared().connectWait(initiator: .threemaCall)
                self.answerAction = action
                
                let action = VoIPCallUserAction(
                    action: .acceptCallKit,
                    contactIdentity: contactIdentity,
                    callID: callID,
                    completion: nil
                )
                
                VoIPCallStateManager.shared.processUserAction(action)
            }
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        Task {
            DDLogNotice(
                "CallKitManager: [cid=\(self.callID?.callID != nil ? String(self.callID!.callID) : "unknown")]: End call action"
            )
            
            // Since we have a suspension point during the launch of the app, but we need to report the call to call kit
            // directly, there might be the case that the user declines the call, before all needed information is
            // available. We there fore wait here for the info to be filled.
            var totalWait = 0.0
            let waitDuration = 0.1
            let maxWaitDuration = 10.0
            
            while VoIPCallStateManager.shared.currentContactIdentity() == nil || VoIPCallStateManager.shared
                .currentCallID() == nil, !dismissCallKitDirectly {
                DDLogNotice(
                    "CallKitManager: [cid=\(String(describing: self.callID?.callID))]: Waiting for call info, total wait time: \(totalWait)s"
                )
                
                try? await Task.sleep(seconds: waitDuration)
                totalWait += waitDuration
                
                if totalWait > maxWaitDuration {
                    DDLogError(
                        "CallKitManager: [cid=\(self.callID?.callID ?? "unknown")]: Timeout waiting for call info. Failing call."
                    )
                    self.dismissCallKitDirectly = false
                    action.fulfill()
                    return
                }
            }
            
            self.dismissCallKitDirectly = false
            
            guard let contactIdentity = VoIPCallStateManager.shared.currentContactIdentity(),
                  let callID = VoIPCallStateManager.shared.currentCallID() else {
                DDLogError(
                    "CallKitManager: [cid=\(self.callID?.callID ?? "unknown")]: Fulfill end call action, but has missing call state"
                )
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
                ServerConnector.shared().connectWait(initiator: .threemaCall)
                let userAction =
                    if VoIPCallStateManager.shared.currentCallState() == .incomingRinging {
                        VoIPCallUserAction(
                            action: .reject,
                            contactIdentity: contactIdentity,
                            callID: callID,
                            completion: {
                                action.fulfill()
                            }
                        )
                    }
                    else {
                        VoIPCallUserAction(
                            action: .end,
                            contactIdentity: contactIdentity,
                            callID: callID,
                            completion: {
                                action.fulfill()
                            }
                        )
                    }
                
                VoIPCallStateManager.shared.processUserAction(userAction)
            }
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        DDLogNotice(
            "CallKitManager: [cid=\(String(describing: self.callID?.callID))]: Muted call action, set muted: \(action.isMuted)"
        )

        guard let contactIdentity = VoIPCallStateManager.shared.currentContactIdentity(),
              let callID = VoIPCallStateManager.shared.currentCallID() else {
            DDLogError(
                "CallKitManager: [cid=\(self.callID?.callID ?? "unknown")]: Fail mute call action due to missing call state"
            )
            action.fail()
            return
        }
        
        BackgroundTaskManager.shared.newBackgroundTask(
            key: kAppVoIPBackgroundTask,
            timeout: Int(kAppVoIPBackgroundTaskTime)
        ) {
            ServerConnector.shared().connectWait(initiator: .threemaCall)
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
        DDLogNotice(
            "CallKitManager: [cid=\(String(describing: self.callID?.callID))]: Held call action, is on hold: \(action.isOnHold)"
        )

        guard let contactIdentity = VoIPCallStateManager.shared.currentContactIdentity(),
              let callID = VoIPCallStateManager.shared.currentCallID() else {
            DDLogError(
                "CallKitManager: [cid=\(self.callID?.callID ?? "unknown")]: Fail hold call action due to missing call state"
            )
            action.fail()
            return
        }
        
        BackgroundTaskManager.shared.newBackgroundTask(
            key: kAppVoIPBackgroundTask,
            timeout: Int(kAppVoIPBackgroundTaskTime)
        ) {
            ServerConnector.shared().connectWait(initiator: .threemaCall)
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
        DDLogNotice(
            "CallKitManager: [cid=\(String(describing: self.callID?.callID))]: Timed out performing call action: \(action.description)"
        )

        guard let contactIdentity = VoIPCallStateManager.shared.currentContactIdentity(),
              let callID = VoIPCallStateManager.shared.currentCallID() else {
            DDLogError(
                "CallKitManager: [cid=\(self.callID?.callID ?? "unknown")]: Fail time out action due to missing call state"
            )
            action.fail()
            return
        }
        
        BackgroundTaskManager.shared.newBackgroundTask(
            key: kAppVoIPBackgroundTask,
            timeout: Int(kAppVoIPBackgroundTaskTime)
        ) {
            ServerConnector.shared().connectWait(initiator: .threemaCall)
            
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
        DDLogNotice("CallKitManager: [cid=\(String(describing: callID?.callID))]: Did activate audio session")
        VoIPCallStateManager.shared.setRTCAudio(audioSession)
    }
}
