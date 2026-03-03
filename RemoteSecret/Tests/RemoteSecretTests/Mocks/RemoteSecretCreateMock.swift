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
import ThreemaEssentials
@testable import RemoteSecret

final class RemoteSecretCreateMock: RemoteSecretCreateProtocol {
    struct CreateInfo: Equatable {
        let workServerBaseURL: String
        let licenseUsername: String
        let licensePassword: String
        let identity: ThreemaIdentity
        let clientKey: Data
    }
    
    var runs = [CreateInfo]()
    
    private let authenticationToken: Data
    private let identityHash: Data
    
    init(authenticationToken: Data, identityHash: Data) {
        self.authenticationToken = authenticationToken
        self.identityHash = identityHash
    }
    
    func run(
        workServerBaseURL: String,
        licenseUsername: String,
        licensePassword: String,
        identity: ThreemaIdentity,
        clientKey: Data,
    ) async throws -> (authenticationToken: Data, identityHash: Data) {
        runs.append(
            CreateInfo(
                workServerBaseURL: workServerBaseURL,
                licenseUsername: licenseUsername,
                licensePassword: licensePassword,
                identity: identity,
                clientKey: clientKey
            )
        )
        return (authenticationToken, identityHash)
    }
}
