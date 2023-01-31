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

@objc public class VoIPCallRingingMessage: NSObject {
    public var contactIdentity: String!
    public var callID: VoIPCallID
    public var completion: (() -> Void)?

    init(callID: VoIPCallID, completion: (() -> Void)?) {
        self.callID = callID
        self.completion = completion
        super.init()
    }
    
    public convenience init(contactIdentity: String, callID: VoIPCallID, completion: (() -> Void)?) {
        self.init(callID: callID, completion: completion)
        self.contactIdentity = contactIdentity
    }
}

// MARK: - VoIPCallMessageProtocol

extension VoIPCallRingingMessage: VoIPCallMessageProtocol {
    
    enum VoIPCallRingingMessageError: Error {
        case generateJson(error: Error)
    }
        
    static func decodeAsObject<T>(_ dictionary: [AnyHashable: Any]) -> T where T: VoIPCallMessageProtocol {
        let tmpCallID = VoIPCallID(callID: dictionary[VoIPCallConstants.callIDKey] as? UInt32)
        return VoIPCallRingingMessage(callID: tmpCallID, completion: nil) as! T
    }
    
    public func encodeAsJson() throws -> Data {
        let json = [VoIPCallConstants.callIDKey: callID.callID] as [AnyHashable: Any]
        do {
            return try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        }
        catch {
            throw VoIPCallRingingMessageError.generateJson(error: error)
        }
    }
}
