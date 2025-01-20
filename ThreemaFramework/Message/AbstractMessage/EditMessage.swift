//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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
import ThreemaProtocols

@objc public final class EditMessage: AbstractMessage {
    public var decoded: CspE2e_EditMessage?

    override public var loggingDescription: String {
        "\(super.loggingDescription); edit ID: \(decoded?.messageID.littleEndianData.hexString ?? "unknown")"
    }
    
    override public func type() -> UInt8 {
        UInt8(MSGTYPE_EDIT)
    }

    override public func canCreateConversation() -> Bool {
        false
    }

    override public func canShowUserNotification() -> Bool {
        false
    }

    override public func flagShouldPush() -> Bool {
        true
    }

    override public func noDeliveryReceiptFlagSet() -> Bool {
        true
    }

    override public func isContentValid() -> Bool {
        decoded != nil
    }

    override public func body() -> Data? {
        guard let serializedData = try? decoded?.serializedData()
        else {
            DDLogError("Unable to create EditMessage body")
            return nil
        }

        var body = Data()
        body.append(serializedData)

        return body
    }

    @objc override public init() {
        super.init()
    }

    @objc func fromRawProtoBufMessage(rawProtobufMessage: NSData) throws {
        decoded = try CspE2e_EditMessage(serializedData: rawProtobufMessage as Data)
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
            self.decoded = try CspE2e_EditMessage(serializedData: Data(data))
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
}
