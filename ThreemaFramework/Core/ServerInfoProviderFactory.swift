import CocoaLumberjackSwift
import Foundation

public final class ServerInfoProviderFactory: NSObject {

    private static let serverInfoProvider: ServerInfoProvider =
        if TargetManager.isOnPrem {
            OnPremServerInfoProvider()
        }
        else {
            PublicServerInfoProvider()
        }

    @objc public static func makeServerInfoProvider() -> ServerInfoProvider {
        ServerInfoProviderFactory.serverInfoProvider
    }

    @objc static func recoveryOnPrem() {
        guard TargetManager.isOnPrem else {
            return
        }

        Task {
            do {
                try await ServerInfoProviderFactory.makeServerInfoProvider().doRecovery()
            }
            catch {
                DDLogError("OnPrem failed to do recovery: \(error)")
            }
        }
    }
}
