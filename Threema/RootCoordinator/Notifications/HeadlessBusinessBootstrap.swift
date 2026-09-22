import CocoaLumberjackSwift
import Foundation
import ThreemaFramework

/// Brings the business layer up without a scene, i.e. without any of the launch UI.
@MainActor
enum HeadlessBusinessBootstrap {

    static func run() async -> Bool {
        do {
            let businessInjector = try await AppLaunchManager.shared.businessForBackgroundLaunch()

            // Without this the redelivered call offer never reaches `VoIPCallStateManager`.
            // `ServerConnector` holds the delegate strongly, as on the launch sequence's path.
            businessInjector.serverConnector.registerMessageProcessorDelegate(delegate: IncomingMessageManager())

            return true
        }
        catch {
            DDLogError("[Call:1to1:HeadlessBusinessBootstrap] Unable to bring up business layer: \(error)")
            return false
        }
    }
}
