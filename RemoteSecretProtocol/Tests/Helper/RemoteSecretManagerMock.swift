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
import RemoteSecretProtocol
import ThreemaEssentials

public final class RemoteSecretManagerMock: RemoteSecretManagerProtocol, @unchecked Sendable {
    
    public let crypto: any RemoteSecretCryptoProtocol
    
    @Atomic
    public private(set) var isRemoteSecretEnabled: Bool
    
    @Atomic
    public private(set) var checkValidityCalls = 0
    
    @Atomic
    public private(set) var stopMonitoringCalls = 0
    
    public init(
        isRemoteSecretEnabled: Bool = false,
        crypto: any RemoteSecretCryptoProtocol = RemoteSecretCryptoMock()
    ) {
        self.isRemoteSecretEnabled = isRemoteSecretEnabled
        self.crypto = crypto
    }
    
    public func checkValidity() {
        $checkValidityCalls.increment()
    }
    
    public func stopMonitoring() async {
        $stopMonitoringCalls.increment()
    }
    
    // MARK: - Helpers
    
    public func resetCalls() {
        checkValidityCalls = 0
    }
}
