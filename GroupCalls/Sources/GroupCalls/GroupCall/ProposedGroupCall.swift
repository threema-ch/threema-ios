//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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
import ThreemaProtocols

/// A potential group call. Either loaded from DB or received as a new message
public struct ProposedGroupCall: Sendable {
    // MARK: - Public Properties

    public let groupRepresentation: GroupCallsThreemaGroupModel
    public let protocolVersion: UInt32
    public let gck: Data
    public let sfuBaseURL: URL
    public let hexCallID: String
    public let startMessageReceiveDate: Date
    
    // MARK: Private Properties

    private let dependencies: Dependencies
    
    // MARK: - Lifecycle
    
    public init(
        groupRepresentation: GroupCallsThreemaGroupModel,
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
