import Foundation
@testable import Threema

/// A configurable implementation of `LicenseMDMSetupProtocol` for testing
struct LicenseMDMSetupMock: LicenseMDMSetupProtocol {

    /// MDM keys that are managed by MDM and must not be overwritten
    var managedKeys: Set<String> = []

    func existsMdmKey(_ mdmKey: String) -> Bool {
        managedKeys.contains(mdmKey)
    }
}
