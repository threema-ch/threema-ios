import CocoaLumberjackSwift
import Foundation
import SwiftProtobuf

extension Message {
    public func ownSerializedData(partial: Bool = false) throws -> Data {
        do {
            return try serializedData(partial: partial)
        }
        catch {
            DDLogError("[GroupCall] Serialization failed: \(error)")
            throw GroupCallError.serializationFailure
        }
    }
}
