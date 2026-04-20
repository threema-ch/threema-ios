import Foundation
import ThreemaFramework

// MARK: - BootstrapUserSettingsProtocol

@MainActor
protocol BootstrapUserSettingsProtocol: AnyObject {
    var acceptedPrivacyPolicyDate: Date? { get set }
    var acceptedPrivacyPolicyVariant: Int { get set }
    var enableMultiDevice: Bool { get set }
    var syncContacts: Bool { get set }
    var safeIntroShown: Bool { get set }
}

// MARK: - BootstrapUserSettingsAdapter

final class BootstrapUserSettingsAdapter: BootstrapUserSettingsProtocol {
    
    private var settings: UserSettings {
        UserSettings.shared()
    }
    
    var acceptedPrivacyPolicyDate: Date? {
        get {
            settings.acceptedPrivacyPolicyDate
        }
        set {
            settings.acceptedPrivacyPolicyDate = newValue
        }
    }
    
    var acceptedPrivacyPolicyVariant: Int {
        get {
            Int(settings.acceptedPrivacyPolicyVariant.rawValue)
        }
        set {
            settings.acceptedPrivacyPolicyVariant =
                AcceptPrivacyPolicyVariant(rawValue: newValue) ?? .update
        }
    }
    
    var enableMultiDevice: Bool {
        get {
            settings.enableMultiDevice
        }
        set {
            settings.enableMultiDevice = newValue
        }
    }
    
    var syncContacts: Bool {
        get {
            settings.syncContacts
        }
        set {
            settings.syncContacts = newValue
        }
    }
    
    var safeIntroShown: Bool {
        get {
            settings.safeIntroShown
        }
        set {
            settings.safeIntroShown = newValue
        }
    }
}
