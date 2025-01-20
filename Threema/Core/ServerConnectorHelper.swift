//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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
import PromiseKit
import ThreemaFramework

class ServerConnectorHelper {
    
    /// Connect to server and wait until connected (if already connected onConnect block will be executed immediately)
    /// - Parameters:
    ///     - initiator: Initiator of server connection
    ///     - timeout: In seconds
    ///     - onConnect: Block will executed if server connection logged in
    ///     - onTimeout: Block will executed if server connection is not logged in after timeout
    class func connectAndWaitUntilConnected(
        initiator: ConnectionInitiator,
        timeout: Int,
        onConnect: @escaping (() -> Void),
        onTimeout: @escaping (() -> Void)
    ) {
        if ServerConnector.shared().connectionState != .loggedIn {
            ServerConnector.shared().connect(initiator: initiator)

            waitUntilConnected(timeout: timeout, onConnect: onConnect, onTimeout: onTimeout)
        }
        else {
            onConnect()
        }
    }

    class func waitUntilConnected(timeout: Int, onConnect: @escaping (() -> Void), onTimeout: @escaping (() -> Void)) {
        if ServerConnector.shared().connectionState == .loggedIn {
            onConnect()
            return
        }

        if timeout > 0, AppGroup.getActiveType() == AppGroupTypeApp {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                self.waitUntilConnected(timeout: timeout - 1, onConnect: onConnect, onTimeout: onTimeout)
            }
        }
        else {
            onTimeout()
        }
    }
}
