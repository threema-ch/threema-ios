//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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
import GroupCalls
import SwiftProtobuf
import ThreemaMacros
import ThreemaProtocols

@objc public final class GroupCallStartMessage: AbstractGroupMessage {
    public var decoded: CspE2e_GroupCallStart?
    
    override public func type() -> UInt8 {
        UInt8(MSGTYPE_GROUP_CALL_START)
    }
    
    override public func flagShouldPush() -> Bool {
        true
    }
    
    override public func allowSendingProfile() -> Bool {
        true
    }
    
    override public func minimumRequiredForwardSecurityVersion() -> ObjcCspE2eFs_Version {
        .V12
    }
    
    @objc var decodedObj: Any {
        decoded as Any
    }
    
    override public func body() -> Data? {
        guard let groupCreatorASCII = groupCreator?.data(using: .ascii),
              let serializedData = try? decoded?.serializedData()
        else {
            let message = "Unable to create GroupCallStartMessage body"
            DDLogError(message)
            return nil
        }
        
        var body = Data()
        body.append(groupCreatorASCII)
        body.append(groupID)
        body.append(serializedData)
        
        return body
    }
    
    override public func pushNotificationBody() -> String! {
        #localize("group_call_notification_body")
    }
    
    override public func isContentValid() -> Bool {
        decoded != nil
    }

    @objc override public init() {
        super.init()
    }
    
    @objc func fromRawProtoBufMessage(rawProtobufMessage: NSData) throws {
        decoded = try CspE2e_GroupCallStart(serializedData: rawProtobufMessage as Data)
    }

    // MARK: NSSecureCoding

    private enum CodingKeys: String, CodingKey {
        case cspMessage
    }

    private enum CodingError: Error {
        case decodeObjectFailed, serializedDataFailed
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        do {
            guard let data = coder.decodeObject(of: NSData.self, forKey: CodingKeys.cspMessage.rawValue) else {
                throw CodingError.decodeObjectFailed
            }
            self.decoded = try CspE2e_GroupCallStart(serializedData: Data(data))
        }
        catch {
            DDLogError("Decoding failed: \(error)")
        }
    }
    
    override public func encode(with coder: NSCoder) {
        super.encode(with: coder)
        do {
            guard let data = try decoded?.serializedData() else {
                throw CodingError.serializedDataFailed
            }
            coder.encode(NSData(data: data), forKey: CodingKeys.cspMessage.rawValue)
        }
        catch {
            DDLogError("Encoding failed: \(error)")
        }
    }

    override public static var supportsSecureCoding: Bool {
        true
    }
    
    override public func isGroupCall() -> Bool {
        true
    }
}
