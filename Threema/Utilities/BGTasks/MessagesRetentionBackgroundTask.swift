import BackgroundTasks
import Foundation
import Keychain
import RemoteSecret

/// Run message retention periodically in the background
struct MessagesRetentionBackgroundTask: ThreemaBackgroundTask {
    let identifier = "ch.threema.bgtask.messageRetention"
    let minimalInterval: TimeInterval = 43200 // 12h
    
    // Only schedule if message retention is enabled
    var shouldSchedule: Bool {
        let mdmDays = MDMSetup().keepMessagesDays() ?? 0
        
        return mdmDays.intValue > 0 || UserSettings.shared().keepMessagesDays > 0
    }
    
    // We directly schedule the task again, so we are not dependent on an app launch
    let shouldReschedule = true
    
    func run() async throws {
        // The app might still be in memory, in which case this reuses what is already set up
        let businessInjector = try await AppLaunchManager.shared.businessForBackgroundLaunch()

        businessInjector.messageRetentionManager.deleteOldMessages()
        
        // We must call disconnect explicitly, since we do not run through one of the app delegate methods when the
        // task completes.
        businessInjector.serverConnector.disconnectWait(initiator: .app)
    }
}
