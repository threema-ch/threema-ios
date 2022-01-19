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

import Foundation
import CocoaLumberjackSwift

class VoIPCallSender: NSObject {
    class func sendVoIPCall(offer: VoIPCallOfferMessage) {
        let msg = BoxVoIPCallOfferMessage()
        do {
            msg.jsonData = try offer.jsonData()
            msg.toIdentity = offer.contact!.identity
            DDLogNotice("VoipCallService: [cid=\(offer.callId.callId)]: Call offer enqueued to \(offer.contact!.identity ?? "?")")
            MessageQueue.shared()?.enqueue(msg)
        } catch let error {
            DDLogError("VoipCallService: [cid=\(offer.callId.callId)]: Can't send offer message to \(offer.contact!.identity ?? "?") -> \(error.localizedDescription)")
        }
    }
    
    class func sendVoIPCall(answer: VoIPCallAnswerMessage) {
        let msg = BoxVoIPCallAnswerMessage()
        do {
            msg.jsonData = try answer.jsonData()
            msg.toIdentity = answer.contact!.identity
            DDLogNotice("VoipCallService: [cid=\(answer.callId.callId)]: Call answer enqueued to \(answer.contact!.identity ?? "?")")
            MessageQueue.shared()?.enqueue(msg)
        }
        catch let error {
            DDLogError("VoipCallService: [cid=\(answer.callId.callId)]: Can't send answer message to \(answer.contact!.identity ?? "?") -> \(error.localizedDescription)")
        }
    }

    class func sendVoIPCall(iceCandidates: VoIPCallIceCandidatesMessage) {
        let msg = BoxVoIPCallIceCandidatesMessage()
        do {
            msg.jsonData = try iceCandidates.jsonData()
            msg.toIdentity = iceCandidates.contact!.identity
            DDLogNotice("VoipCallService: [cid=\(iceCandidates.callId.callId)]: Call ICE candidate message enqueued to \(iceCandidates.contact?.identity ?? "?") (\(iceCandidates.candidates.count) candidates")
            for candidate in iceCandidates.candidates {
                DDLogNotice("VoipCallService: [cid=\(iceCandidates.callId.callId)]: Outgoing ICE candidate: \(candidate.sdp)")
            }
            MessageQueue.shared()?.enqueue(msg)
        }
        catch let error {
            DDLogError("VoipCallService: [cid=\(iceCandidates.callId.callId)]: Can't send ice candidates message \(iceCandidates.contact!.identity ?? "?") -> \(error.localizedDescription)")
        }
    }
    
    class func sendVoIPCallHangup(hangupMessage: VoIPCallHangupMessage, wait: Bool) {
        let msg = BoxVoIPCallHangupMessage()
        do {
            msg.jsonData = try hangupMessage.jsonData()
            msg.toIdentity = hangupMessage.contact.identity
            DDLogNotice("VoipCallService: [cid=\(hangupMessage.callId.callId)]: Call hangup message enqueued to \(hangupMessage.contact.identity ?? "?")")
            if wait == true {
                MessageQueue.shared()?.enqueueWait(msg)
            } else {
                MessageQueue.shared()?.enqueue(msg)
            }
        }
        catch let error {
            DDLogError("VoipCallService: [cid=\(hangupMessage.callId.callId)]: Can't send hangup message to \(hangupMessage.contact.identity ?? "?") -> \(error.localizedDescription)")
        }
    }
    
    class func sendVoIPCallRinging(ringingMessage: VoIPCallRingingMessage) {
        let msg = BoxVoIPCallRingingMessage()
        do {
            msg.jsonData = try ringingMessage.jsonData()
            msg.toIdentity = ringingMessage.contact.identity
            DDLogNotice("VoipCallService: [cid=\(ringingMessage.callId.callId)]: Call ringing message enqueued to \(ringingMessage.contact.identity ?? "?")")
            MessageQueue.shared()?.enqueue(msg)
        }
        catch let error {
            DDLogError("VoipCallService: [cid=\(ringingMessage.callId.callId)]: Can't send call ringing message to \(ringingMessage.contact.identity ?? "?") -> \(error.localizedDescription)")
        }
    }
}
