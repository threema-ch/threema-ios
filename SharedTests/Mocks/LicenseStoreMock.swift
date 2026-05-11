import Foundation
import ThreemaFramework

// MARK: - LicenseStoreMock

/// A fully mockable implementation of `LicenseStoreProtocol` for testing.
public final class LicenseStoreMock: NSObject, LicenseStoreProtocol {
    
    // MARK: - Properties
    
    public var errorMessage: String?
    public var error: Error?
    
    public var licenseUsername: String?
    public var licensePassword: String?
    public var licenseDeviceID = ""
    public var onPremConfigURL: String?
    
    // MARK: - Configurable Behavior
    
    public var isValidResult = true
    public var isWithinCheckIntervalResult = true
    public var isWithinOfflineIntervalResult = true
    public var performLicenseCheckResult = true
    public var validCustomOnPremConfigURLResult = true
    
    // MARK: - Call Tracking
    
    public var performLicenseCheckCalled = false
    public var performUpdateWorkInfoCalled = false
    public var performUpdateWorkInfoForceCalled = false
    public var deleteLicenseCalled = false
    
    // MARK: - Initialization
    
    override public init() {
        super.init()
    }
    
    // MARK: - LicenseStoreProtocol
    
    public func validCustomOnPremConfigURL(predefinedURL: String) -> Bool {
        validCustomOnPremConfigURLResult
    }
    
    public func isValid() -> Bool {
        isValidResult
    }
    
    public func isWithinCheckInterval() -> Bool {
        isWithinCheckIntervalResult
    }
    
    public func isWithinOfflineInterval() -> Bool {
        isWithinOfflineIntervalResult
    }
    
    public func performLicenseCheck(completion: @escaping (Bool) -> Void) {
        performLicenseCheckCalled = true
        completion(performLicenseCheckResult)
    }
    
    public func performUpdateWorkInfo(force: Bool) {
        performUpdateWorkInfoForceCalled = true
    }
    
    public func performUpdateWorkInfo() {
        performUpdateWorkInfoCalled = true
    }
    
    public func deleteLicense() {
        deleteLicenseCalled = true
        licenseUsername = nil
        licensePassword = nil
        onPremConfigURL = nil
    }
    
    // swiftformat:disable:next all
    public func validCustomOnPremConfigUrl(withPredefinedUrl onPremConfigUrl: String!) -> Bool {
        validCustomOnPremConfigURLResult
    }
}
