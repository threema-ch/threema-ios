import CocoaLumberjackSwift
import Foundation
import ThreemaEssentials

/// A Group Call ID as described by the protocol
struct GroupCallID: Sendable {
    // MARK: - Internal Properties

    let bytes: Data
    
    // MARK: - Lifecycle

    init(
        groupIdentity: GroupIdentity,
        callStartData: GroupCallStartData,
        dependencies: Dependencies
    ) throws {
        let creatorID = Data(groupIdentity.creator.rawValue.utf8)
        let groupID = groupIdentity.id
        let protocolVersion = Data(repeating: UInt8(callStartData.protocolVersion), count: 1)
        let gck = callStartData.gck
        let baseURL = Data(callStartData.sfuBaseURL.absoluteString.utf8)
        
        let inputs = [creatorID, groupID, protocolVersion, gck, baseURL]
        
        self.bytes = try GroupCallKeys.deriveCallID(from: inputs)
    }
}

// MARK: - CustomStringConvertible

extension GroupCallID: CustomStringConvertible {
    var description: String {
        bytes.hexEncodedString()
    }
}

// MARK: - Equatable

extension GroupCallID: Equatable { }
