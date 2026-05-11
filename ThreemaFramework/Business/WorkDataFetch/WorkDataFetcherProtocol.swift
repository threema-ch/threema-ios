import CocoaLumberjackSwift
import Foundation

/// Protocol for fetching and applying Threema Work/OnPrem (business) data.
public protocol WorkDataFetcherProtocol {
    /// Full work data sync: contacts, MDM settings, logos, org info, company directory.
    /// - Parameters:
    ///   - force: If `true`, bypasses the check interval gate and fetches immediately.
    ///   - forceSend: Whether we send updated info to our backend
    func checkUpdateWorkData(force: Bool, forceSendMDM: Bool) async throws

    /// Reset last sync date to enforce a full Work Sync when `checkUpdateWorkData` is called next time.
    func resetLastSync()
}
