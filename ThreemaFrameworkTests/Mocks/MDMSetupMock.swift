import Foundation
@testable import ThreemaFramework

/// A mock implementation of `MDMSetupProtocol` for testing purposes.
///
/// This mock conforms to `MDMSetupProtocol` and tracks calls to `applyThreemaMdm(_:sendForce:)`
/// which is needed for testing MDM application logic.
final class MDMSetupMock: MDMSetupProtocol {
    
    // MARK: - Configuration
    
    /// Whether to return `true` from `disableWorkDirectory()`.
    var mockDisableWorkDirectory = false
    
    // MARK: - Captured Values
    
    /// The number of times `applyThreemaMdm(_:sendForce:)` was called.
    private(set) var applyThreemaMdmCallCount = 0
    
    /// The work data dictionary from the last `applyThreemaMdm(_:sendForce:)` call.
    private(set) var lastAppliedWorkData: [AnyHashable: Any]?
    
    /// The `sendForce` parameter from the last `applyThreemaMdm(_:sendForce:)` call.
    private(set) var lastAppliedSendForce: Bool?
    
    // MARK: - Initialization
    
    init() { }
    
    // MARK: - MDMSetupProtocol
    
    func applyThreemaMdm(_ workData: [AnyHashable: Any]?, sendForce: Bool) {
        applyThreemaMdmCallCount += 1
        lastAppliedWorkData = workData
        lastAppliedSendForce = sendForce
    }
    
    // MARK: - Other Protocol Methods
    
    func isSafeBackupDisable() -> Bool { false }
    func isSafeBackupForce() -> Bool { false }
    func isSafeBackupPasswordPreset() -> Bool { false }
    func isSafeBackupServerPreset() -> Bool { false }
    func isSafeRestoreDisable() -> Bool { false }
    func isSafeRestoreForce() -> Bool { false }
    func isSafeRestorePasswordPreset() -> Bool { false }
    func isSafeRestoreServerPreset() -> Bool { false }
    
    func safeEnable() -> NSNumber? { nil }
    func safePassword() -> String? { nil }
    func safePasswordPattern() -> String? { nil }
    func safePasswordMessage() -> String? { nil }
    func safeServerURL() -> String? { nil }
    func safeServerUsername() -> String? { nil }
    func safeServerPassword() -> String? { nil }
    
    func disableIDExport() -> Bool { false }
    func disableWorkDirectory() -> Bool { mockDisableWorkDirectory }
}
