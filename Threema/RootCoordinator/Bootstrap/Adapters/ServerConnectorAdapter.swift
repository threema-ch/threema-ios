import Foundation
import ThreemaFramework

// MARK: - ServerConnectionInitiator

enum ServerConnectionInitiator {
    case app
    case notificationServiceExtension
    case shareExtension
    case notificationHandler
    case threemaCall
    case threemaWeb
    
    var frameworkInitiator: ConnectionInitiator {
        switch self {
        case .app:
            .app
        case .notificationServiceExtension:
            .notificationExtension
        case .shareExtension:
            .shareExtension
        case .notificationHandler:
            .notificationHandler
        case .threemaCall:
            .threemaCall
        case .threemaWeb:
            .threemaWeb
        }
    }
}

// MARK: - ServerConnectionState

enum ServerConnectionState {
    case disconnected
    case connecting
    case connected
    case loggedIn
    case disconnecting
    
    init(frameworkConnectionState: ConnectionState) {
        switch frameworkConnectionState {
        case .disconnected:
            self = .disconnected
        case .connecting:
            self = .connecting
        case .connected:
            self = .connected
        case .loggedIn:
            self = .loggedIn
        case .disconnecting:
            self = .disconnecting
        @unknown default:
            self = .disconnected
        }
    }
}

// MARK: - ServerConnectorAdapterProtocol

protocol ServerConnectorAdapterProtocol: Sendable {
    var connectionState: ServerConnectionState { get }
    var isAppInBackground: Bool { get set }
    func connect(_ initiator: ServerConnectionInitiator) async -> Bool
    func removePushToken() async
}

// MARK: - ServerConnectorAdapter

final class ServerConnectorAdapter: ServerConnectorAdapterProtocol {
    
    private var connector: ServerConnector {
        ServerConnector.shared()
    }
    
    var connectionState: ServerConnectionState {
        ServerConnectionState(
            frameworkConnectionState: connector.connectionState
        )
    }
    
    var isAppInBackground: Bool {
        get {
            connector.isAppInBackground
        }
        set {
            connector.isAppInBackground = newValue
        }
    }
    
    func connect(_ initiator: ServerConnectionInitiator) async -> Bool {
        await withCheckedContinuation { continuation in
            connector.connect(
                initiator: initiator.frameworkInitiator,
                completionHandler: { isConnected in
                    continuation.resume(returning: isConnected)
                }
            )
        }
    }
    
    func removePushToken() async {
        await MainActor.run {
            connector.removePushToken()
        }
    }
}
