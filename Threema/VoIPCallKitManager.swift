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
import CallKit

protocol VoIPCallKitManagerDelegate: class {
    func callFailed()
}


final class VoIPCallKitManager: NSObject {
    
    private let provider: CXProvider
    private let callController: CXCallController
    private var uuid: UUID?
    private var answerAction: CXAnswerCallAction?
    
    weak var delegate: VoIPCallKitManagerDelegate?
    
    override init() {
        provider = CXProvider(configuration: VoIPCallKitManager.providerConfiguration(contact: nil))
        callController = CXCallController.init()
        super.init()
        provider.setDelegate(self, queue: nil)
    }
    
    class func providerConfiguration(contact: Contact?) -> CXProviderConfiguration {
        let providerConfiguration = CXProviderConfiguration(localizedName: BundleUtil.localizedString(forKey: "call_callkit_button_title"))
        providerConfiguration.supportsVideo = true
        providerConfiguration.maximumCallGroups = 1
        providerConfiguration.maximumCallsPerCallGroup = 1
        providerConfiguration.supportedHandleTypes = [.generic]
        
        if contact != nil {
            if let pushSetting = PushSetting.find(forIdentity: contact!.identity) {
                if pushSetting.canSendPush() && pushSetting.silent == false {
                    let voIPSound = UserSettings.shared()?.voIPSound
                    if voIPSound != "default" {
                        providerConfiguration.ringtoneSound = "\(voIPSound!).caf"
                    }
                } else {
                    providerConfiguration.ringtoneSound = "silent.mp3"
                }
            } else {
                let voIPSound = UserSettings.shared()?.voIPSound
                if voIPSound != "default" {
                    providerConfiguration.ringtoneSound = "\(voIPSound!).caf"
                }
            }
        }
        
        let image = BundleUtil.imageNamed("VoipThreema")
        providerConfiguration.iconTemplateImageData = image?.pngData()
        return providerConfiguration
    }
}

extension VoIPCallKitManager {
    // MARK: Public functions
    
    func reportIncomingCall(uuid: UUID, contact: Contact) {
        provider.configuration = VoIPCallKitManager.providerConfiguration(contact: contact)
        let update = CXCallUpdate.init()
        update.remoteHandle = CXHandle.init(type: .generic, value: contact.identity)
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsHolding = false
        update.supportsDTMF = false
        update.hasVideo = false
        update.localizedCallerName = contact.displayName
        
        RTCAudioSession.sharedInstance().useManualAudio = true
        VoIPCallKitManager.configureAudioSession()
        
        provider.reportNewIncomingCall(with: uuid, update: update) { (error) in
            if error != nil {
                self.delegate?.callFailed()
            } else {
                self.uuid = uuid
            }
        }
    }
    
    func startCall(contact: Contact) {
        let handle = CXHandle.init(type: .generic, value: contact.identity)
        uuid = UUID.init()
        
        let startCallAction = CXStartCallAction.init(call: uuid!, handle: handle)
        let transaction = CXTransaction.init(action: startCallAction)
        callController.request(transaction, completion: { (error) in
            if error != nil {
                self.delegate?.callFailed()
            }
            let update = CXCallUpdate()
            update.remoteHandle = CXHandle.init(type: .generic, value: contact.identity)
            update.hasVideo = false
            update.localizedCallerName = contact.displayName
            self.provider.reportCall(with: self.uuid!, updated: update)
        })
    }
    
    func callAccepted() {
        if let callId = uuid {
            provider.reportOutgoingCall(with: callId, startedConnectingAt: Date())
        }
    }
    
    func callConnected() {
        if let callId = uuid {
            provider.reportOutgoingCall(with: callId, connectedAt: Date())
            answerAction?.fulfill()
        }
    }
    
    func answerFailed() {
        answerAction?.fail()
    }
    
    func endCall() {
        if let callId = uuid {
            let action = CXEndCallAction.init(call: callId)
            let transaction = CXTransaction.init(action: action)
            self.callController.request(transaction, completion: { (error) in
                // do noting
            })
        }
    }
    
    func timeoutCall() {
        if let id = uuid {
            let action = CXEndCallAction.init(call: id)
            let transaction = CXTransaction.init(action: action)
            self.callController.request(transaction, completion: { (error) in
                // do noting
            })
        }
    }
    func rejectCall() {
        if let id = uuid {
            let action = CXEndCallAction.init(call: id)
            let transaction = CXTransaction.init(action: action)
            self.callController.request(transaction, completion: { (error) in
                // do noting
            })
        }
    }
    
    static func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setActive(true)
        } catch let error {
            print(error.localizedDescription)
        }
    }
}

extension VoIPCallKitManager: CXProviderDelegate {
    // MARK: CXProviderDelegate
    func providerDidReset(_ provider: CXProvider) {
        let state = VoIPCallStateManager.shared.currentCallState()
        if state == .incomingRinging || state == .calling || state == .reconnecting {
            if let contact = VoIPCallStateManager.shared.currentCallContact() {
                if let currentCallId = VoIPCallStateManager.shared.currentCallId() {
                    BackgroundTaskManager.shared.newBackgroundTask(key: kAppVoIPBackgroundTask, timeout: Int(kAppVoIPBackgroundTaskTime)) {
                        ServerConnector.shared()?.connectWait()
                        var userAction: VoIPCallUserAction?
                        if VoIPCallStateManager.shared.currentCallState() == .incomingRinging {
                            userAction = VoIPCallUserAction.init(action: .reject, contact: contact, callId: currentCallId, completion: nil)
                        } else {
                            userAction = VoIPCallUserAction.init(action: .end, contact: contact, callId: currentCallId, completion: nil)
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
        if let contact = VoIPCallStateManager.shared.currentCallContact() {
            if let currentCallId = VoIPCallStateManager.shared.currentCallId() {
                BackgroundTaskManager.shared.newBackgroundTask(key: kAppVoIPBackgroundTask, timeout: Int(kAppPushBackgroundTaskTime)) {
                    ServerConnector.shared()?.connectWait()
                    self.answerAction = action
                    VoIPCallKitManager.configureAudioSession()
                    let action = VoIPCallUserAction.init(action: .acceptCallKit, contact: contact, callId: currentCallId, completion: nil)
                    VoIPCallStateManager.shared.processUserAction(action)
                }
            }
        } else {
            action.fail()
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        guard let contact = VoIPCallStateManager.shared.currentCallContact() else {
            action.fulfill()
            return
        }
        guard let callId = VoIPCallStateManager.shared.currentCallId() else {
            action.fulfill()
            return
        }
        
        let state = VoIPCallStateManager.shared.currentCallState()
        switch state {
        case .ended, .remoteEnded, .rejected, .rejectedBusy, .rejectedTimeout, .rejectedDisabled, .rejectedOffHours, .rejectedUnknown, .microphoneDisabled:
            action.fulfill()
            return
        case .idle, .sendOffer, .receivedOffer, .outgoingRinging, .incomingRinging, .sendAnswer, .receivedAnswer, .initalizing, .calling, .reconnecting:
            // do nothing
            break
        }
                
        BackgroundTaskManager.shared.newBackgroundTask(key: kAppVoIPBackgroundTask, timeout: Int(kAppPushBackgroundTaskTime)) {
            ServerConnector.shared()?.connectWait()
            var userAction: VoIPCallUserAction?
            if VoIPCallStateManager.shared.currentCallState() == .incomingRinging {
                userAction = VoIPCallUserAction.init(action: .reject, contact: contact, callId: callId, completion: {
                    action.fulfill()
                })
            } else {
                userAction = VoIPCallUserAction.init(action: .end, contact: contact, callId: callId, completion: {
                    action.fulfill()
                })
            }
            VoIPCallStateManager.shared.processUserAction(userAction!)
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        guard let contact = VoIPCallStateManager.shared.currentCallContact() else {
            action.fail()
            return
        }
        guard let callId = VoIPCallStateManager.shared.currentCallId() else {
            action.fail()
            return
        }
        
        BackgroundTaskManager.shared.newBackgroundTask(key: kAppVoIPBackgroundTask, timeout: Int(kAppVoIPBackgroundTaskTime)) {
            ServerConnector.shared()?.connectWait()
            let actionType: VoIPCallUserAction.Action = action.isMuted ? .muteAudio : .unmuteAudio
            let userAction = VoIPCallUserAction.init(action: actionType, contact: contact, callId: callId, completion: {
                action.fulfill()
            })
            VoIPCallStateManager.shared.processUserAction(userAction)
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        guard let contact = VoIPCallStateManager.shared.currentCallContact() else {
            action.fail()
            return
        }
        guard let callId = VoIPCallStateManager.shared.currentCallId() else {
            action.fail()
            return
        }
        
        BackgroundTaskManager.shared.newBackgroundTask(key: kAppVoIPBackgroundTask, timeout: Int(kAppVoIPBackgroundTaskTime)) {
            ServerConnector.shared()?.connectWait()
            let actionType: VoIPCallUserAction.Action = action.isOnHold ? .muteAudio : .unmuteAudio
            let action = VoIPCallUserAction.init(action: actionType, contact: contact, callId: callId, completion: {
                action.fulfill()
            })
            VoIPCallStateManager.shared.processUserAction(action)
        }
    }
    
    func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        guard let contact = VoIPCallStateManager.shared.currentCallContact() else {
            action.fulfill()
            return
        }
        guard let callId = VoIPCallStateManager.shared.currentCallId() else {
            action.fulfill()
            return
        }
        
        BackgroundTaskManager.shared.newBackgroundTask(key: kAppVoIPBackgroundTask, timeout: Int(kAppVoIPBackgroundTaskTime)) {
            ServerConnector.shared()?.connectWait()
            
            switch VoIPCallStateManager.shared.currentCallState() {
            case .idle, .ended, .remoteEnded, .rejected, .rejectedBusy, .rejectedTimeout, .rejectedOffHours, .rejectedUnknown, .rejectedDisabled, .microphoneDisabled:
                action.fulfill()
                break
            case .sendOffer, .outgoingRinging, .sendAnswer, .receivedAnswer, .initalizing, .calling, .reconnecting:
                let userAction = VoIPCallUserAction.init(action: .end, contact: contact, callId: callId, completion: {
                    action.fulfill()
                })
                VoIPCallStateManager.shared.processUserAction(userAction)
                break
            case .receivedOffer, .incomingRinging:
                let userAction = VoIPCallUserAction.init(action: .rejectUnknown, contact: contact, callId: callId, completion: {
                    action.fulfill()
                })
                VoIPCallStateManager.shared.processUserAction(userAction)
                break
            }
        }
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        VoIPCallStateManager.shared.setRTCAudio(audioSession)
    }
}
