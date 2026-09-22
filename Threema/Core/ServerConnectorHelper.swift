import Foundation
import PromiseKit
import ThreemaFramework

enum ServerConnectorHelper {

    /// Connect to server and wait until connected (if already connected onConnect block will be executed immediately)
    /// - Parameters:
    ///     - initiator: Initiator of server connection
    ///     - timeout: In seconds
    ///     - onConnect: Block will executed if server connection logged in
    ///     - onTimeout: Block will executed if server connection is not logged in after timeout
    static func connectAndWaitUntilConnected(
        initiator: ConnectionInitiator,
        timeout: Int,
        onConnect: @escaping (() -> Void),
        onTimeout: @escaping (() -> Void)
    ) {
        // Also register the initiator when we are already connected, otherwise the connection is not claimed and
        // someone else disconnects it while it is still needed
        ServerConnector.shared().connect(initiator: initiator)

        if ServerConnector.shared().connectionState != .loggedIn {
            waitUntilConnected(timeout: timeout, onConnect: onConnect, onTimeout: onTimeout)
        }
        else {
            onConnect()
        }
    }

    private static func waitUntilConnected(
        timeout: Int,
        onConnect: @escaping (() -> Void),
        onTimeout: @escaping (() -> Void)
    ) {
        if ServerConnector.shared().connectionState == .loggedIn {
            onConnect()
            return
        }

        if timeout > 0,
           !UserSettings.shared().ipcCommunicationEnabled && AppGroup.getActiveType() == AppGroupTypeApp || UserSettings
           .shared().ipcCommunicationEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                waitUntilConnected(timeout: timeout - 1, onConnect: onConnect, onTimeout: onTimeout)
            }
        }
        else {
            onTimeout()
        }
    }
}
