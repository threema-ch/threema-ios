import AVFAudio
import CocoaLumberjackSwift
import Foundation

/// Microphone access of the app, shared with its extensions
///
/// Use this instead of `AVAudioApplication`, which only reports the access that was cached when the process asked for
/// it the first time. The process of the Notification Extension is reused for multiple pushes, thus it might never see
/// an access that was granted in the app in the meantime and would keep rejecting calls.
public enum RecordPermission {

    public enum Access: Int, Comparable {
        /// Nothing was stored yet or the stored access is not readable
        case unknown = 0
        /// The user was never asked for access
        case undetermined = 1
        case denied = 2
        case granted = 3

        public static func < (lhs: Access, rhs: Access) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    private static let userDefaultsKey = "\(TargetManager.localizedAppName)MicrophoneAccess"

    public static var access: Access {
        // Neither value can be trusted on its own, because each process might have cached its own before the access
        // was changed. Thus take the one that knows more: an access is never undetermined again after the user was
        // asked once. (A revoked access terminates the app, thus it is stored again with the next launch.)
        max(currentProcessAccess, storedAccess)
    }

    public static var isGranted: Bool {
        access == .granted
    }

    /// Ask the user for access to the microphone and store the result
    public static func requestPermission(completionHandler: @escaping (Bool) -> Void) {
        AVAudioApplication.requestRecordPermission { isGranted in
            store(isGranted ? .granted : .denied)

            completionHandler(isGranted)
        }
    }

    /// Ask the user for access to the microphone and store the result
    @discardableResult
    public static func requestPermission() async -> Bool {
        let isGranted = await AVAudioApplication.requestRecordPermission()

        store(isGranted ? .granted : .denied)

        return isGranted
    }

    /// Call this after every launch of the app, the access can also be changed in the settings of the device
    public static func storeCurrentAccess() {
        store(currentProcessAccess)
    }

    // MARK: - Private functions

    /// - Parameter access: Result of a request, don't read the access again because it might not be updated yet
    private static func store(_ access: Access) {
        guard access != .unknown, access != storedAccess else {
            return
        }

        AppGroup.userDefaults().set(access.rawValue, forKey: userDefaultsKey)

        DDLogNotice("[RecordPermission] Access changed to \(access)")
    }

    private static var currentProcessAccess: Access {
        switch AVAudioApplication.shared.recordPermission {
        case .undetermined: .undetermined
        case .denied: .denied
        case .granted: .granted
        @unknown default: .unknown
        }
    }

    private static var storedAccess: Access {
        Access(rawValue: AppGroup.userDefaults().integer(forKey: userDefaultsKey)) ?? .unknown
    }
}
