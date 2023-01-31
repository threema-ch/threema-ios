//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2023 Threema GmbH
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

extension RTCSessionDescription {
        
    enum RTCSessionDescriptionError: Error {
        case generateJson(error: Error)
        case unknownSdpType(unknownType: String)
    }
    
    class func description(from dictionary: [AnyHashable: Any]) -> RTCSessionDescription {
        let type = RTCSessionDescription.type(for: dictionary[VoIPCallConstants.JSON_ANSWER_ANSWER_SDPTYPE] as! String)
        let sdp = dictionary[VoIPCallConstants.JSON_ANSWER_ANSWER_SDP]
        return RTCSessionDescription(type: type, sdp: sdp as! String)
    }
}

extension String {
    func substring(with nsrange: NSRange) -> Substring? {
        guard let range = Range(nsrange, in: self) else {
            return nil
        }
        return self[range]
    }
}
