import Foundation
import ThreemaProtocols

/// A potential group call. Either loaded from DB or received as a new message
public struct ProposedGroupCall: Sendable {
    // MARK: - Public Properties

    public let groupRepresentation: GroupCallThreemaGroupModel
    public let protocolVersion: UInt32
    public let gck: Data
    public let sfuBaseURL: URL
    public let hexCallID: String
    public let startMessageReceiveDate: Date
    
    // MARK: Private Properties

    private let dependencies: Dependencies
    
    // MARK: - Lifecycle
    
    public init(
        groupRepresentation: GroupCallThreemaGroupModel,
        protocolVersion: UInt32,
        gck: Data,
        sfuBaseURL: URL,
        startMessageReceiveDate: Date,
        dependencies: Dependencies
    ) throws {
        self.groupRepresentation = groupRepresentation
        self.protocolVersion = protocolVersion
        self.gck = gck
        self.sfuBaseURL = sfuBaseURL
        self.dependencies = dependencies
        self.startMessageReceiveDate = startMessageReceiveDate
        
        let callID = try GroupCallID(
            groupIdentity: groupRepresentation.groupIdentity,
            callStartData: GroupCallStartData(protocolVersion: protocolVersion, gck: gck, sfuBaseURL: sfuBaseURL),
            dependencies: dependencies
        ).bytes.hexEncodedString()
        self.hexCallID = callID
    }
}
