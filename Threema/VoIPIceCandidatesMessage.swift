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

@objc class VoIPCallIceCandidatesMessage: NSObject {
    @objc let removed: Bool
    @objc let candidates: [RTCIceCandidate]
    @objc var contact: Contact?
    @objc let callId: VoIPCallId
    var completion: (() -> Void)?
    
    @objc init(removed: Bool, candidates: [RTCIceCandidate], contact: Contact?, callId: VoIPCallId, completion: (() -> Void)?) {
        self.removed = removed
        self.candidates = candidates
        self.contact = contact
        self.callId = callId
        self.completion = completion
        super.init()
    }
}

extension VoIPCallIceCandidatesMessage {
    
    enum VoIPCallIceCandidatesMessageError: Error {
        case generateJson(error: Error)
    }
    
    enum Keys: String {
        case removed = "removed"
        case candidates = "candidates"
        case candidate = "candidate"
        case sdpMid = "sdpMid"
        case sdpMLineIndex = "sdpMLineIndex"
        case ufrag = "ufrag"
        case callId = "callId"
    }
    
    @objc class func iceCandidates(dictionary: [AnyHashable: Any]) -> VoIPCallIceCandidatesMessage {
        let removed = dictionary[Keys.removed.rawValue] as! Bool
        let tmpCandidates = dictionary[Keys.candidates.rawValue] as? [[AnyHashable: Any]]
        var candidates = [RTCIceCandidate]()
        
        if tmpCandidates != nil {
            for (_, dict) in tmpCandidates!.enumerated() {
                let sdp = dict[Keys.candidate.rawValue] as! String
                let sdpMLineIndex = dict[Keys.sdpMLineIndex.rawValue] as! Int32
                let sdpMid = dict[Keys.sdpMid.rawValue] as! String
                let candidate = RTCIceCandidate.init(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
                candidates.append(candidate)
            }
        }
        let tmpCallId = VoIPCallId(callId: dictionary[Keys.callId.rawValue] as? UInt32)

        let message = VoIPCallIceCandidatesMessage.init(removed: removed, candidates: candidates, contact: nil, callId: tmpCallId, completion: nil)
        return message
    }
    
    @objc func jsonData() throws -> Data {
        var candidates = [[AnyHashable: Any]]()
        for (_, candidate) in self.candidates.enumerated() {
            var dict = [AnyHashable: Any]()
            dict[Keys.candidate.rawValue] = candidate.sdp
            dict[Keys.sdpMid.rawValue] = candidate.sdpMid
            dict[Keys.sdpMLineIndex.rawValue] = candidate.sdpMLineIndex
            candidates.append(dict)
        }
        let json = [Keys.callId.rawValue: callId.callId, Keys.removed.rawValue: self.removed, Keys.candidates.rawValue: candidates] as [AnyHashable : Any]
        do {
            return try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        }
        catch let error {
            throw VoIPCallIceCandidatesMessageError.generateJson(error: error)
        }
    }
}
