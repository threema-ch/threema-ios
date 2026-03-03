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

import Keychain
import RemoteSecretProtocol

/// Access all remote secret functionality after initialization
///
/// Use `RemoteSecretManagerCreator` to create this manager. This should only be done once during app launch or during
/// setup
final class RemoteSecretManager: RemoteSecretManagerProtocol {
    
    let isRemoteSecretEnabled = true
    
    let crypto: any RemoteSecretCryptoProtocol
    
    private let monitor: any RemoteSecretMonitorSwiftProtocol
    private let keychainManagerType: any KeychainManagerProtocol.Type

    init(
        crypto: any RemoteSecretCryptoProtocol,
        monitor: any RemoteSecretMonitorSwiftProtocol,
        keychainManagerType: any KeychainManagerProtocol.Type
    ) {
        self.crypto = crypto
        self.monitor = monitor
        self.keychainManagerType = keychainManagerType
    }
    
    func checkValidity() {
        Task.detached { [weak self] in
            await self?.monitor.runCheck()
        }
    }
    
    func stopMonitoring() async {
        // Ensure that the remote secret was already deleted from keychain
        let remoteSecret = try? keychainManagerType.loadRemoteSecret()
        guard remoteSecret == nil else {
            return
        }
        
        await monitor.stop()
    }
}
