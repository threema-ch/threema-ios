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
import ThreemaFramework
import ThreemaMacros

protocol VoIPCallKitManagerDelegate: AnyObject {
    func currentCallPartnerIdentity() -> String
    func currentCallID() -> VoIPCallID
    func setRTCAudio(_ audioSession: AVAudioSession)
}

final class VoIPCallKitManager: NSObject {

    weak var delegate: VoIPCallKitManagerDelegate?
    
    private let provider: CXProvider
    private let callController: CXCallController
    private let callIDService: CallIDService

    private var answerAction: CXAnswerCallAction?
    
    /// The call will be set to true if a call fails, ends, or is rejected by the application. If CallKit triggers one
    /// of these actions, we will have a loop to wait until all information is loaded. This value will bypass the loop
    /// to close CallKit directly.
    private var dismissCallKitDirectly = false

    override init() {
        self.provider = CXProvider(configuration: VoIPCallKitManager.providerConfiguration())
        self.callController = CXCallController()
        self.callIDService = CallIDService()
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
    ///
    /// - Parameters:
    ///   - callID: Unique call ID
    ///   - callPartnerIdentity: Caller identity
    ///   - ringtoneSound: Filename of ringtone to be used
    ///   - businessInjector: BusinessInjector instance to get call partner display name
    ///   - completion: Completion handler returns nil if call successfully reported to CallKit
    func reportIncomingCall(
        with callID: VoIPCallID,
        callPartnerIdentity: String,
        ringtoneSound: String,
        businessInjector: BusinessInjectorProtocol,
        completion: @escaping (Error?) -> Void
    ) {
        reportIncomingCall(
            with: callID,
            callPartnerIdentity: callPartnerIdentity,
            callPartnerName: callPartnerName(for: callPartnerIdentity, businessInjector: businessInjector),
            ringtoneSound: ringtoneSound,
            completion: completion
        )
    }

    /// Report new incoming call to CallKit.
    ///
    /// - Parameters:
    ///   - callID: Unique call ID
    ///   - callPartnerIdentity: Caller identity
    ///   - callPartnerName: Caller name
    ///   - ringtoneSound: Filename of ringtone to be used
    ///   - completion: Completion handler returns error or nil
    func reportIncomingCall(
        with callID: VoIPCallID,
        callPartnerIdentity: String,
        callPartnerName: String?,
        ringtoneSound: String,
        completion: @escaping (Error?) -> Void
    ) {
        guard ThreemaEnvironment.supportsCallKit() else {
            DDLogError("VoipCallService: [cid=\(callID.callID)]: CallKit is not supported in this environment.")
            fatalError("VoIPCallKitManager is not supported in this environment.")
        }
        
        provider.configuration = VoIPCallKitManager.providerConfiguration(ringtoneSound: ringtoneSound)
        
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: callPartnerIdentity)
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsHolding = false
        update.supportsDTMF = false
        update.hasVideo = false
        update.localizedCallerName = callPartnerName ?? callPartnerIdentity

        RTCAudioSession.sharedInstance().useManualAudio = true

        let (uuid, isNew) = callIDService.uuid(for: callID)
        if isNew {
            DDLogNotice("VoipCallService: [cid=\(callID.callID)]: Report new incoming call -> (callUUUID=\(uuid)")
            provider.reportNewIncomingCall(with: uuid, update: update) { error in
                if let error {
                    DDLogError(
                        "CallKitManager: [cid=\(callID.callID)]: Report new incoming call failed (CallKit UUID: \(uuid): \(error)"
                    )
                }
                completion(error)
            }
        }
        else {
            DDLogNotice("VoipCallService: [cid=\(callID.callID)]: Report incoming call -> (callUUUID=\(uuid)")
            provider.reportCall(with: uuid, updated: update)
        }
    }
    
    func startCall(
        with callID: VoIPCallID,
        for callPartnerIdentity: String,
        businessInjector: BusinessInjectorProtocol
    ) {
        guard ThreemaEnvironment.supportsCallKit() else {
            DDLogError("VoipCallService: [cid=\(callID.callID)]: CallKit is not supported in this environment.")
            fatalError("VoIPCallKitManager is not supported in this environment.")
        }
        
        let handle = CXHandle(type: .generic, value: callPartnerIdentity)

        let (uuid, isNew) = callIDService.uuid(for: callID)
        assert(isNew)
        let startCallAction = CXStartCallAction(call: uuid, handle: handle)
        let transaction = CXTransaction(action: startCallAction)
        callController.request(transaction) { error in
            
            if let error {
                DDLogError(
                    "CallKitManager: [cid=\(callID.callID)]: Start call action failed (CallKit UUID: \(uuid): \(error)"
                )
                return
            }
            
            let update = CXCallUpdate()
            update.remoteHandle = CXHandle(type: .generic, value: callPartnerIdentity)
            update.hasVideo = false
            update.localizedCallerName = self.callPartnerName(
                for: callPartnerIdentity,
                businessInjector: businessInjector
            )

            self.provider.reportCall(with: uuid, updated: update)
        }
    }
    
    func callAccepted(with callID: VoIPCallID) {
        guard ThreemaEnvironment.supportsCallKit() else {
            assertionFailure()
            DDLogWarn("VoipCallService: [cid=\(callID.callID)]: CallKit is not supported in this environment.")
            return
        }
        
        let (uuid, isNew) = callIDService.uuid(for: callID)
        assert(!isNew)
        provider.reportOutgoingCall(with: uuid, startedConnectingAt: Date())
    }
    
    func callConnected(with callID: VoIPCallID) {
        guard ThreemaEnvironment.supportsCallKit() else {
            assertionFailure()
            DDLogWarn("VoipCallService: [cid=\(callID.callID)]: CallKit is not supported in this environment.")
            return
        }
        
        let (uuid, isNew) = callIDService.uuid(for: callID)
        assert(!isNew)
        provider.reportOutgoingCall(with: uuid, connectedAt: Date())
        answerAction?.fulfill()
    }
    
    func answerFailed() {
        answerAction?.fail()
    }
    
    func endCall(with callID: VoIPCallID) {
        guard ThreemaEnvironment.supportsCallKit() else {
            DDLogWarn("VoipCallService: [cid=\(callID.callID)]: CallKit is not supported in this environment.")
            return
        }
        
        dismissCallKitDirectly = true
        let (uuid, isNew) = callIDService.uuid(for: callID)
        assert(!isNew)
        let action = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: action)
        callController.request(transaction) { error in
            if let error {
                DDLogError(
                    "CallKitManager: [cid=\(callID.callID)]: End call action failed (CallKit UUID: \(uuid): \(error)"
                )
            }
        }
    }
    
    func timeoutCall(with callID: VoIPCallID) {
        guard ThreemaEnvironment.supportsCallKit() else {
            assertionFailure()
            DDLogWarn("VoipCallService: [cid=\(callID.callID)]: CallKit is not supported in this environment.")
            return
        }
        
        let (uuid, isNew) = callIDService.uuid(for: callID)
        assert(!isNew)
        let action = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: action)
        callController.request(transaction) { error in
            if let error {
                DDLogError(
                    "CallKitManager: [cid=\(callID.callID)]: Timeout call action failed (CallKit UUID: \(uuid): \(error)"
                )
            }
        }
    }

    /// Report CallKit for unknown call push.
    func startAndCancelCall(from localizedName: String, completion: @escaping () -> Void) {
        guard ThreemaEnvironment.supportsCallKit() else {
            assertionFailure()
            DDLogWarn("VoipCallService: CallKit is not supported in this environment.")
            return
        }
        
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: localizedName)
        update.supportsDTMF = false
        update.supportsHolding = false
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.hasVideo = false

        let uuid = UUID()

        provider.reportNewIncomingCall(with: uuid, update: update) { _ in
            Task { @MainActor in
                let localizedMessage = #localize("call_missed")
                NotificationManager.showThreemaWebError(title: TargetManager.appName, body: localizedMessage)
            }

            self.provider.reportCall(with: uuid, endedAt: Date(), reason: .failed)
            completion()
        }

        // Prevent ringing
        provider.reportCall(with: uuid, endedAt: .now, reason: .failed)
    }

    // MARK: - Private functions

    private func callPartnerName(for identity: String, businessInjector: BusinessInjectorProtocol) -> String {
        let entityManager = businessInjector.entityManager
        return entityManager.performAndWait {
            if let contact = entityManager.entityFetcher.contactEntity(for: identity) {
                contact.displayName
            }
            else {
                identity
            }
        }
    }
    
    private func removePendingActions(for callID: UUID) {
        let pendingActions = provider.pendingCallActions(of: CXCallAction.self, withCall: callID)
        guard let actionCallID = callIDService.callID(for: callID), !pendingActions.isEmpty else {
            return
        }
        
        for action in pendingActions {
            DDLogNotice(
                "CallKitManager: [cid=\(actionCallID.callID)] Failing pending action \(action) for call with UUID \(callID)"
            )
            action.fail()
        }
    }
}

// MARK: - CXProviderDelegate

extension VoIPCallKitManager: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        guard let callID = delegate?.currentCallID(),
              let callPartnerIdentity = delegate?.currentCallPartnerIdentity() else {
            DDLogError("CallKitManager: Did not handle provider reset due to missing call state")
            return
        }
        
        let state = VoIPCallStateManager.shared.currentCallState()
        guard state == .incomingRinging || state == .calling || state == .reconnecting else {
            DDLogError(
                "CallKitManager: [cid=\(callID.callID)]: Did not handle provider reset due to being in wrong call state: \(state.rawValue)"
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
                        contactIdentity: callPartnerIdentity,
                        callID: callID,
                        completion: nil
                    )
                }
                else {
                    VoIPCallUserAction(
                        action: .end,
                        contactIdentity: callPartnerIdentity,
                        callID: callID,
                        completion: nil
                    )
                }
                    
            VoIPCallStateManager.shared.addActionToCallQueue(userAction)
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        guard let actionCallID = callIDService.callID(for: action.callUUID) else {
            action.fail()
            return
        }

        DDLogNotice("CallKitManager: [cid=\(actionCallID.callID)]: Start call action")

        assert(delegate?.currentCallID().callID == actionCallID.callID)

        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        Task {
            guard let actionCallID = callIDService.callID(for: action.callUUID) else {
                action.fulfill()
                return
            }

            DDLogNotice("CallKitManager: [cid=\(actionCallID)]: Answer call action")

            // Since we have a suspension point during the launch of the app, but we need to report the call to call kit
            // directly, there might be the case that the user answers the call, before all needed information is
            // available. We there fore wait here for the info to be filled.
            var totalWait = 0.0
            let waitDuration = 0.1
            let maxWaitDuration = 10.0
            
            while delegate?.currentCallPartnerIdentity() == nil || delegate?
                .currentCallID() == nil {
                DDLogNotice(
                    "CallKitManager: [cid=\(actionCallID.callID)]: Waiting for call info, total wait time: \(totalWait)s"
                )
                
                try? await Task.sleep(seconds: waitDuration)
                totalWait += waitDuration
                
                if totalWait > maxWaitDuration {
                    DDLogError(
                        "CallKitManager: [cid=\(actionCallID.callID)]: Timeout waiting for call info. Failing call."
                    )
                    action.fail()
                    return
                }
            }

            guard let currentCallID = delegate?.currentCallID(),
                  let contactIdentity = delegate?.currentCallPartnerIdentity(),
                  currentCallID.callID == actionCallID.callID else {
                DDLogError(
                    "CallKitManager: [cid=\(actionCallID.callID)]: Fail answer call action, because the call ID or call partner identity is missing or current call ID is not equal to that action"
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
                    callID: currentCallID,
                    completion: {
                        action.fulfill()
                    }
                )
                
                VoIPCallStateManager.shared.addActionToCallQueue(action)
            }
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        Task {
            guard let actionCallID = callIDService.callID(for: action.callUUID) else {
                action.fulfill()
                removePendingActions(for: action.callUUID)
                return
            }

            DDLogNotice("CallKitManager: [cid=\(actionCallID.callID)]: End call action")

            // Since we have a suspension point during the launch of the app, but we need to report the call to call kit
            // directly, there might be the case that the user declines the call, before all needed information is
            // available. We there fore wait here for the info to be filled.
            var totalWait = 0.0
            let waitDuration = 0.1
            let maxWaitDuration = 10.0
            
            while delegate?.currentCallPartnerIdentity() == nil || delegate?
                .currentCallID() == nil, !dismissCallKitDirectly {
                DDLogNotice(
                    "CallKitManager: [cid=\(actionCallID.callID))]: Waiting for call info, total wait time: \(totalWait)s"
                )
                
                try? await Task.sleep(seconds: waitDuration)
                totalWait += waitDuration
                
                if totalWait > maxWaitDuration {
                    DDLogError(
                        "CallKitManager: [cid=\(actionCallID.callID)]: Timeout waiting for call info. Failing call."
                    )
                    self.dismissCallKitDirectly = false
                    action.fulfill()
                    removePendingActions(for: action.callUUID)
                    return
                }
            }
            
            self.dismissCallKitDirectly = false
            
            guard let currentCallID = delegate?.currentCallID(),
                  let callPartnerIdentity = delegate?.currentCallPartnerIdentity(),
                  currentCallID.callID == actionCallID.callID else {
                DDLogError(
                    "CallKitManager: [cid=\(actionCallID.callID)]: Fulfill end call action, but call ID or call partner identity is missing or current call ID is not equal to that action"
                )
                action.fulfill()
                removePendingActions(for: action.callUUID)
                return
            }
            
            let state = VoIPCallStateManager.shared.currentCallState()
            switch state {
            case .ended, .remoteEnded, .rejected, .rejectedBusy, .rejectedTimeout, .rejectedDisabled, .rejectedOffHours,
                 .rejectedUnknown, .microphoneDisabled:
                let userAction = VoIPCallUserAction(
                    action: .end,
                    contactIdentity: callPartnerIdentity,
                    callID: currentCallID,
                    completion: {
                        action.fulfill()
                        self.removePendingActions(for: action.callUUID)
                    }
                )
                VoIPCallStateManager.shared.addActionToCallQueue(userAction)
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
                            contactIdentity: callPartnerIdentity,
                            callID: currentCallID,
                            completion: {
                                action.fulfill()
                                self.removePendingActions(for: action.callUUID)
                            }
                        )
                    }
                    else {
                        VoIPCallUserAction(
                            action: .end,
                            contactIdentity: callPartnerIdentity,
                            callID: currentCallID,
                            completion: {
                                action.fulfill()
                                self.removePendingActions(for: action.callUUID)
                            }
                        )
                    }
                
                VoIPCallStateManager.shared.addActionToCallQueue(userAction)
            }
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        let callID = callIDService.callID(for: action.callUUID)
        assert(delegate?.currentCallID().callID == callID?.callID)

        DDLogNotice(
            "CallKitManager: [cid=\(String(describing: callID?.callID))]: Muted call action, set muted: \(action.isMuted)"
        )

        guard let callID = delegate?.currentCallID(),
              let callPartnerIdentity = delegate?.currentCallPartnerIdentity() else {
            DDLogError(
                "CallKitManager: [cid=\(callID?.callID ?? "unknown")]: Fail mute call action due to missing call state"
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
                contactIdentity: callPartnerIdentity,
                callID: callID,
                completion: {
                    action.fulfill()
                }
            )
            
            VoIPCallStateManager.shared.addActionToCallQueue(userAction)
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        let callID = callIDService.callID(for: action.callUUID)
        assert(delegate?.currentCallID().callID == callID?.callID)

        DDLogNotice(
            "CallKitManager: [cid=\(String(describing: callID?.callID))]: Held call action, is on hold: \(action.isOnHold)"
        )

        guard let callID = delegate?.currentCallID(),
              let callPartnerIdentity = delegate?.currentCallPartnerIdentity() else {
            DDLogError(
                "CallKitManager: [cid=\(callID?.callID ?? "unknown")]: Fail hold call action due to missing call state"
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
                contactIdentity: callPartnerIdentity,
                callID: callID,
                completion: {
                    action.fulfill()
                }
            )
            
            VoIPCallStateManager.shared.addActionToCallQueue(action)
        }
    }
    
    func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        guard let callID = delegate?.currentCallID(),
              let callPartnerIdentity = delegate?.currentCallPartnerIdentity() else {
            DDLogError("CallKitManager: Fail time out action due to missing call state")
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
                    contactIdentity: callPartnerIdentity,
                    callID: callID,
                    completion: {
                        action.fulfill()
                    }
                )
                VoIPCallStateManager.shared.addActionToCallQueue(userAction)
                
            case .receivedOffer, .incomingRinging:
                let userAction = VoIPCallUserAction(
                    action: .rejectUnknown,
                    contactIdentity: callPartnerIdentity,
                    callID: callID,
                    completion: {
                        action.fulfill()
                    }
                )
                VoIPCallStateManager.shared.addActionToCallQueue(userAction)
            }
        }
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        let callID = delegate?.currentCallID()
        DDLogNotice("CallKitManager: [cid=\(String(describing: callID?.callID))]: Did activate audio session")
        delegate?.setRTCAudio(audioSession)
    }
}
