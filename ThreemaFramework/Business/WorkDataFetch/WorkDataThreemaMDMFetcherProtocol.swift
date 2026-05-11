import Foundation

/// A protocol defining the interface for fetching and applying Threema MDM (Mobile Device Management) configurations.
public protocol WorkDataThreemaMDMFetcherProtocol {
    
    /// Processes raw MDM data and applies the configuration to the device.
    ///
    /// This method parses the provided JSON data, validates it for errors,
    /// and applies the MDM configuration using the system's `MDMSetup`.
    ///
    /// - Parameter data: The raw JSON `Data` containing MDM configuration from the Work API.
    /// - Parameter forceSend:
    func processAndApply(_ data: Data, forceSend: Bool) async throws
    
    /// Checks for and applies any pending Threema MDM configuration updates.
    ///
    /// This method fetches the latest MDM configuration from the Work API and applies
    /// any changes to the device. It only performs the update if the app is a business
    /// (Threema Work) app and valid credentials are available.
    ///
    /// - Parameter forceSend:
    /// - Note: This method silently returns without action if called on a non-business app.
    func checkUpdateThreemaMDM(forceSend: Bool) async throws
}
