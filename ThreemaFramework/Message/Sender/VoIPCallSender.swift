import CocoaLumberjackSwift
import Foundation
import ThreemaEssentials

public final class VoIPCallSender {
    private let messageSender: any MessageSenderProtocol
    private let myIdentity: ThreemaIdentity
    private let isMultiDeviceEnabled: Bool

    // MARK: - Lifecycle
    
    public init(
        messageSender: any MessageSenderProtocol,
        myIdentity: ThreemaIdentity,
        isMultiDeviceEnabled: Bool
    ) {
        self.messageSender = messageSender
        self.myIdentity = myIdentity
        self.isMultiDeviceEnabled = isMultiDeviceEnabled
    }
    
    // MARK: - Public functions
    
    public func sendVoIPCall(offer: VoIPCallOfferMessage) {
        let msg = BoxVoIPCallOfferMessage()
        do {
            msg.jsonData = try offer.encodeAsJson()
            msg.toIdentity = offer.contactIdentity
            msg.fromIdentity = myIdentity.rawValue

            DDLogNotice(
                "VoipCallService: [cid=\(offer.callID)]: Call offer enqueued to \(offer.contactIdentity ?? "?")"
            )
            
            // When multi device is enabled, we need a transaction to send this type of message
            if isMultiDeviceEnabled {
                messageSender.sendTransactionRequiredCallMessage(abstractMessage: msg, callID: offer.callID)
            }
            else {
                messageSender.sendMessage(abstractMessage: msg, isPersistent: false)
            }
        }
        catch {
            DDLogError(
                "VoipCallService: [cid=\(offer.callID)]: Can't send offer message to \(offer.contactIdentity ?? "?") -> \(error.localizedDescription)"
            )
        }
    }
    
    public func sendVoIPCall(answer: VoIPCallAnswerMessage) {
        let msg = BoxVoIPCallAnswerMessage()
        do {
            msg.jsonData = try answer.encodeAsJson()
            msg.toIdentity = answer.contactIdentity
            msg.fromIdentity = myIdentity.rawValue
            msg.isUserInteraction = answer.isUserInteraction
                        
            DDLogNotice(
                "VoipCallService: [cid=\(answer.callID)]: Call answer enqueued to \(answer.contactIdentity ?? "?"): \(answer.action.description)"
            )

            // When multi device is enabled, we need a transaction to send this type of message
            if isMultiDeviceEnabled {
                messageSender.sendTransactionRequiredCallMessage(abstractMessage: msg, callID: answer.callID)
            }
            else {
                messageSender.sendMessage(abstractMessage: msg, isPersistent: false)
            }
        }
        catch {
            DDLogError(
                "VoipCallService: [cid=\(answer.callID)]: Can't send answer message to \(answer.contactIdentity ?? "?") -> \(error.localizedDescription)"
            )
        }
    }

    public func sendVoIPCall(iceCandidates: VoIPCallIceCandidatesMessage) {
        let msg = BoxVoIPCallIceCandidatesMessage()
        do {
            msg.jsonData = try iceCandidates.encodeAsJson()
            msg.toIdentity = iceCandidates.contactIdentity
            msg.fromIdentity = myIdentity.rawValue

            DDLogNotice(
                "VoipCallService: [cid=\(iceCandidates.callID)]: Call ICE candidate message enqueued to \(iceCandidates.contactIdentity ?? "?") (\(iceCandidates.candidates.count) candidates)"
            )
            
            for candidate in iceCandidates.candidates {
                DDLogNotice(
                    "VoipCallService: [cid=\(iceCandidates.callID)]: Outgoing ICE candidate: \(candidate.sdp)"
                )
            }

            messageSender.sendMessage(abstractMessage: msg, isPersistent: false)
        }
        catch {
            DDLogError(
                "VoipCallService: [cid=\(iceCandidates.callID)]: Can't send ice candidates message \(iceCandidates.contactIdentity ?? "?") -> \(error.localizedDescription)"
            )
        }
    }
    
    public func sendVoIPCallHangup(hangupMessage: VoIPCallHangupMessage, wait: Bool = true) {
        if Thread.isMainThread, wait == true {
            let msg =
                "sendVoIPCallHangup may not be called on the main thread when wait is true. Wait will be disabled."
            assertionFailure(msg)
            DDLogError("\(msg)")
        }
        
        let msg = BoxVoIPCallHangupMessage()
        do {
            msg.jsonData = try hangupMessage.encodeAsJson()
            msg.toIdentity = hangupMessage.contactIdentity
            msg.fromIdentity = myIdentity.rawValue

            DDLogNotice(
                "VoipCallService: [cid=\(hangupMessage.callID)]: Call hangup message enqueued to \(hangupMessage.contactIdentity ?? "?")"
            )
        
            if wait, !Thread.isMainThread {
                var dispatchGroup: DispatchGroup? = DispatchGroup()
                dispatchGroup?.enter()
                
                messageSender.sendMessage(abstractMessage: msg, isPersistent: false, completion: {
                    dispatchGroup?.leave()
                    dispatchGroup = nil
                })
                
                // We only wait when there is a connection, or if it is being built up. Otherwise the UI freezes and one
                // cannot escape the situation.
                let state = ServerConnector.shared().connectionState
                let wait =
                    if state == .connecting || state == .connected || state == .loggedIn {
                        5
                    }
                    else {
                        10
                    }
                
                let result = dispatchGroup?.wait(timeout: .now() + .seconds(wait))
                
                if let result, result == .timedOut {
                    DDLogWarn("Sending hangup message timed out")
                }
            }
            else {
                messageSender.sendMessage(abstractMessage: msg, isPersistent: false)
            }
        }
        catch {
            DDLogError(
                "VoipCallService: [cid=\(hangupMessage.callID)]: Can't send hangup message to \(hangupMessage.contactIdentity ?? "?") -> \(error.localizedDescription)"
            )
        }
    }
    
    public func sendVoIPCallRinging(ringingMessage: VoIPCallRingingMessage) {
        let msg = BoxVoIPCallRingingMessage()
        do {
            msg.jsonData = try ringingMessage.encodeAsJson()
            msg.toIdentity = ringingMessage.contactIdentity
            msg.fromIdentity = myIdentity.rawValue

            DDLogNotice(
                "VoipCallService: [cid=\(ringingMessage.callID)]: Call ringing message enqueued to \(ringingMessage.contactIdentity ?? "?")"
            )

            messageSender.sendMessage(abstractMessage: msg, isPersistent: false)
        }
        catch {
            DDLogError(
                "VoipCallService: [cid=\(ringingMessage.callID)]: Can't send call ringing message to \(ringingMessage.contactIdentity ?? "?") -> \(error.localizedDescription)"
            )
        }
    }
}
