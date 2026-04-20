import Foundation
import libthreemaSwift

protocol RemoteSecretMonitorProtocolResolver {
    func createProtocol(
        clientInfo: ClientInfo,
        workServerBaseURLString: String,
        remoteSecretAuthenticationToken: Data,
        remoteSecretVerifier: RemoteSecretVerifier
    ) throws -> any RemoteSecretMonitorProtocolProtocol
}

// MARK: - Default implementation

struct DefaultRemoteSecretMonitorProtocolResolver: RemoteSecretMonitorProtocolResolver {
    func createProtocol(
        clientInfo: ClientInfo,
        workServerBaseURLString: String,
        remoteSecretAuthenticationToken: Data,
        remoteSecretVerifier: RemoteSecretVerifier
    ) throws -> any RemoteSecretMonitorProtocolProtocol {
        try RemoteSecretMonitorProtocol(
            clientInfo: clientInfo,
            // swiftformat:disable:next acronyms
            workServerBaseUrl: workServerBaseURLString,
            remoteSecretAuthenticationToken: remoteSecretAuthenticationToken,
            remoteSecretVerifier: remoteSecretVerifier
        )
    }
}
