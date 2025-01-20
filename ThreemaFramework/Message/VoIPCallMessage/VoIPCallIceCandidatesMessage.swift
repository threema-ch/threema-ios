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

import Foundation
import WebRTC

@objc public class VoIPCallIceCandidatesMessage: NSObject {
    public let removed: Bool
    public let candidates: [RTCIceCandidate]
    public var contactIdentity: String?
    public let callID: VoIPCallID
    public var completion: (() -> Void)?
    
    public init(
        removed: Bool,
        candidates: [RTCIceCandidate],
        contactIdentity: String?,
        callID: VoIPCallID,
        completion: (() -> Void)?
    ) {
        self.removed = removed
        self.candidates = candidates
        self.contactIdentity = contactIdentity
        self.callID = callID
        self.completion = completion
        super.init()
    }
}

// MARK: - VoIPCallMessageProtocol

extension VoIPCallIceCandidatesMessage: VoIPCallMessageProtocol {
    
    enum VoIPCallIceCandidatesMessageError: Error {
        case generateJson(error: Error)
    }
    
    enum Keys: String {
        case removed
        case candidates
        case candidate
        case sdpMid
        case sdpMLineIndex
        case ufrag
    }
    
    static func decodeAsObject<T>(_ dictionary: [AnyHashable: Any]) -> T where T: VoIPCallMessageProtocol {
        let removed = dictionary[Keys.removed.rawValue] as! Bool
        let tmpCandidates = dictionary[Keys.candidates.rawValue] as? [[AnyHashable: Any]]
        var candidates = [RTCIceCandidate]()
        
        if tmpCandidates != nil {
            for (_, dict) in tmpCandidates!.enumerated() {
                let sdp = dict[Keys.candidate.rawValue] as! String
                let sdpMLineIndex = dict[Keys.sdpMLineIndex.rawValue] as! Int32
                let sdpMid = dict[Keys.sdpMid.rawValue] as! String
                let candidate = RTCIceCandidate(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
                candidates.append(candidate)
            }
        }
        let tmpCallID = VoIPCallID(callID: dictionary[VoIPCallConstants.callIDKey] as? UInt32)

        return VoIPCallIceCandidatesMessage(
            removed: removed,
            candidates: candidates,
            contactIdentity: nil,
            callID: tmpCallID,
            completion: nil
        ) as! T
    }
    
    public func encodeAsJson() throws -> Data {
        var candidates = [[AnyHashable: Any]]()
        for (_, candidate) in self.candidates.enumerated() {
            var dict = [AnyHashable: Any]()
            dict[Keys.candidate.rawValue] = candidate.sdp
            dict[Keys.sdpMid.rawValue] = candidate.sdpMid
            dict[Keys.sdpMLineIndex.rawValue] = candidate.sdpMLineIndex
            candidates.append(dict)
        }
        let json = [
            VoIPCallConstants.callIDKey: callID.callID,
            Keys.removed.rawValue: removed,
            Keys.candidates.rawValue: candidates,
        ] as [AnyHashable: Any]
        do {
            return try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        }
        catch {
            throw VoIPCallIceCandidatesMessageError.generateJson(error: error)
        }
    }
}
