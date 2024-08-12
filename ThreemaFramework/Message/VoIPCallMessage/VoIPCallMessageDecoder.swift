//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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

import CocoaLumberjackSwift
import Foundation

@objc class VoIPCallMessageDecoder: NSObject {
    @objc class func decodeVoIPCallOffer(from: BoxVoIPCallOfferMessage) -> VoIPCallOfferMessage? {
        decode(from.jsonData)
    }
    
    @objc class func decodeVoIPCallAnswer(from: BoxVoIPCallAnswerMessage) -> VoIPCallAnswerMessage? {
        decode(from.jsonData)
    }
    
    @objc class func decodeVoIPCallHangup(
        from: BoxVoIPCallHangupMessage,
        contactIdentity: String
    ) -> VoIPCallHangupMessage? {
        let msg: VoIPCallHangupMessage? =
            if let jsonData = from.jsonData {
                decode(jsonData)
            }
            else {
                VoIPCallHangupMessage(callID: VoIPCallID(callID: nil), completion: nil)
            }
        msg?.contactIdentity = contactIdentity
        msg?.date = from.date
        
        return msg
    }
    
    @objc class func decodeVoIPCallIceCandidates(from: BoxVoIPCallIceCandidatesMessage)
        -> VoIPCallIceCandidatesMessage? {
        decode(from.jsonData)
    }
    
    @objc class func decodeVoIPCallRinging(
        from: BoxVoIPCallRingingMessage,
        contactIdentity: String
    ) -> VoIPCallRingingMessage? {
        let msg: VoIPCallRingingMessage? =
            if let jsonData = from.jsonData {
                decode(jsonData)
            }
            else {
                VoIPCallRingingMessage(callID: VoIPCallID(callID: nil), completion: nil)
            }
        msg?.contactIdentity = contactIdentity
        
        return msg
    }
    
    private class func decode<T: VoIPCallMessageProtocol>(_ jsonData: Data) -> T? {
        do {
            if let dic = try JSONSerialization
                .jsonObject(with: jsonData, options: .mutableContainers) as? [AnyHashable: Any] {
                return T.decodeAsObject(dic)
            }
        }
        catch {
            DDLogError("Error decode voip call message \(error)")
        }
        
        return nil
    }
}
