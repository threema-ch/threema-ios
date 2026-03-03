//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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
import libthreemaSwift
import ThreemaEssentials

public final class RemoteSecretMonitorProtocolMock: RemoteSecretMonitorProtocolProtocol {
    
    public enum PollResponse {
        case request(HttpsRequest)
        case schedule(timeout: TimeInterval, remoteSecret: Data?)
        case error(RemoteSecretMonitorError)
        
        func map() throws -> RemoteSecretMonitorInstruction {
            switch self {
            case let .request(request):
                return .request(request)
            case let .schedule(timeout: timeout, remoteSecret: remoteSecret):
                return .schedule(timeout: timeout, remoteSecret: remoteSecret)
            case let .error(error):
                throw error
            }
        }
    }
    
    public let pollResponses: Atomic<[PollResponse]> = Atomic(wrappedValue: [])
    public let responses: Atomic<[HttpsResult]> = Atomic(wrappedValue: [])
    
    public init(pollResponses: [PollResponse]) {
        self.pollResponses.wrappedValue = pollResponses
    }
    
    public func poll() throws -> RemoteSecretMonitorInstruction {
        try pollResponses.wrappedValue.removeFirst().map()
    }
    
    public func response(response: HttpsResult) throws {
        responses.wrappedValue.append(response)
    }
}
