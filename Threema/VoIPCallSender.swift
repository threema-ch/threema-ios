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
import CocoaLumberjackSwift

class VoIPCallSender: NSObject {
    class func sendVoIPCall(offer: VoIPCallOfferMessage) {
        let msg = BoxVoIPCallOfferMessage()
        do {
            msg.jsonData = try offer.jsonData()
            msg.toIdentity = offer.contact!.identity
            DDLogNotice("Threema call: send offer to \(offer.contact!.identity ?? "?") with callId \(offer.callId.callId)")
            MessageQueue.shared()?.enqueue(msg)
        } catch let error {
            DDLogError("Threema call: Can't send offer message to \(offer.contact!.identity ?? "?") with callId \(offer.callId.callId)) -> \(error.localizedDescription)")
        }
    }
    
    class func sendVoIPCall(answer: VoIPCallAnswerMessage) {
        let msg = BoxVoIPCallAnswerMessage()
        do {
            msg.jsonData = try answer.jsonData()
            msg.toIdentity = answer.contact!.identity
            DDLogNotice("Threema call: send answer to \(answer.contact!.identity ?? "?") with callId \(answer.callId.callId)")
            MessageQueue.shared()?.enqueue(msg)
        }
        catch let error {
            DDLogError("Threema call: Can't send answer message to \(answer.contact!.identity ?? "?") with callId \(answer.callId.callId)) -> \(error.localizedDescription)")
        }
    }

    class func sendVoIPCall(iceCandidates: VoIPCallIceCandidatesMessage) {
        let msg = BoxVoIPCallIceCandidatesMessage()
        do {
            msg.jsonData = try iceCandidates.jsonData()
            msg.toIdentity = iceCandidates.contact!.identity
            DDLogNotice("Threema call: send iceCandidates to \(iceCandidates.contact!.identity ?? "?") with callId \(iceCandidates.callId.callId)")
            MessageQueue.shared()?.enqueue(msg)
        }
        catch let error {
            DDLogError("Threema call: Can't send ice candidates message \(iceCandidates.contact!.identity ?? "?") with callId \(iceCandidates.callId.callId)) -> \(error.localizedDescription)")
        }
    }
    
    class func sendVoIPCallHangup(hangupMessage: VoIPCallHangupMessage, wait: Bool) {
        let msg = BoxVoIPCallHangupMessage()
        do {
            msg.jsonData = try hangupMessage.jsonData()
            msg.toIdentity = hangupMessage.contact.identity
            DDLogNotice("Threema call: send hangup to \(hangupMessage.contact.identity ?? "?") with callId \(hangupMessage.callId.callId)")
            if wait == true {
                MessageQueue.shared()?.enqueueWait(msg)
            } else {
                MessageQueue.shared()?.enqueue(msg)
            }
        }
        catch let error {
            DDLogError("Threema call: Can't send hangup message to \(hangupMessage.contact.identity ?? "?") with callId \(hangupMessage.callId.callId)) -> \(error.localizedDescription)")
        }
    }
    
    class func sendVoIPCallRinging(ringingMessage: VoIPCallRingingMessage) {
        let msg = BoxVoIPCallRingingMessage()
        do {
            msg.jsonData = try ringingMessage.jsonData()
            msg.toIdentity = ringingMessage.contact.identity
            DDLogNotice("Threema call: send ringing to \(ringingMessage.contact.identity ?? "?") with callId \(ringingMessage.callId.callId)")
            MessageQueue.shared()?.enqueue(msg)
        }
        catch let error {
            DDLogError("Threema call: Can't send ringing message to \(ringingMessage.contact.identity ?? "?") with callId \(ringingMessage.callId.callId)) -> \(error.localizedDescription)")
        }
    }
}
