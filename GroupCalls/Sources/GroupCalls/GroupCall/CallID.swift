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

/// A GroupCallID as described by the protocol
struct GroupCallID: Sendable {
    // MARK: - Internal Properties

    let bytes: Data
    
    // MARK: - Lifecycle

    init(
        group: GroupCallsThreemaGroupModel,
        callStartData: GroupCallStartData,
        dependencies: Dependencies
    ) throws {
        guard let creatorID = group.creator.id.data(using: .utf8) else {
            let msg = "Could not encode group creator ID"
            assertionFailure(msg)
            DDLogError(msg)
            
            throw GroupCallError.encryptionFailure
        }
        
        let groupID = group.groupID
        
        let protocolVersion = Data(repeating: UInt8(callStartData.protocolVersion), count: 1)
        
        let gck = callStartData.gck
        
        guard let baseURL = callStartData.sfuBaseURL.data(using: .utf8) else {
            let msg = "Could not encode sfu base url"
            assertionFailure(msg)
            DDLogError(msg)
            
            throw GroupCallError.encryptionFailure
        }
        
        let inputs = [creatorID, groupID, protocolVersion, gck, baseURL]
        
        self.bytes = try GroupCallKeys.deriveCallID(from: inputs, dependencies: dependencies)
    }
}

// MARK: - Equatable

extension GroupCallID: Equatable { }
