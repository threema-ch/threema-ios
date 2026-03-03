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
import Keychain
import RemoteSecretProtocol

/// Container object to prevent exposure of `RemoteSecretManagerProtocol` to Objective-C
@available(*, deprecated, message: "Only use to pass Remote Secret and Keychain Manager through Objective-C")
@objc public class RemoteSecretAndKeychainObjC: NSObject {
    public let remoteSecretManager: any RemoteSecretManagerProtocol
    public let keychainManager: any KeychainManagerProtocol
    
    public init(remoteSecretManager: any RemoteSecretManagerProtocol, keychainManager: any KeychainManagerProtocol) {
        self.remoteSecretManager = remoteSecretManager
        self.keychainManager = keychainManager
    }
}
