import Foundation

/// The incoming call currently ringing in the app, so the Notification Extension can wake the app for its hangup.
/// Expires after `maximumAge`.
public enum RingingCallRecord {
    private static let callIDKey = "RingingIncomingCallID"
    private static let dateKey = "RingingIncomingCallDate"

    /// Longer than an incoming call can ring (60 s)
    static let maximumAge: TimeInterval = 90

    public static func setRinging(_ callID: VoIPCallID, at date: Date = .now) {
        defaults.set(Int(callID.callID), forKey: callIDKey)
        defaults.set(date.timeIntervalSince1970, forKey: dateKey)
    }

    public static func clear(_ callID: VoIPCallID) {
        guard storedCallID() == Int(callID.callID) else {
            return
        }
        remove()
    }

    public static func isRinging(_ callID: VoIPCallID, now: Date = .now) -> Bool {
        guard let stored = storedCallID(),
              let setAt = defaults.object(forKey: dateKey) as? TimeInterval else {
            return false
        }

        guard now.timeIntervalSince1970 - setAt <= maximumAge else {
            remove()
            return false
        }

        return stored == Int(callID.callID)
    }

    // MARK: - Private

    /// Typed, `AppGroup.userDefaults()` comes in as an implicitly unwrapped optional
    private static var defaults: UserDefaults {
        AppGroup.userDefaults()
    }

    private static func storedCallID() -> Int? {
        defaults.object(forKey: callIDKey) as? Int
    }

    private static func remove() {
        defaults.removeObject(forKey: callIDKey)
        defaults.removeObject(forKey: dateKey)
    }
}
