import CocoaLumberjackSwift
import GroupCalls
import ThreemaEssentials
import ThreemaFramework

@MainActor
final class CallProvider {
    // MARK: - Singleton

    static let shared = CallProvider()
    
    // MARK: - Properties
    
    private(set) weak var callLauncher: CallLauncher?

    // MARK: - Init

    private init() { }

    // MARK: - Public

    func setCallLauncher(_ launcher: CallLauncher) {
        guard callLauncher == nil else {
            return
        }
        
        callLauncher = launcher
    }

    func startOutgoingCall(with identity: String) {
        guard let callLauncher else {
            DDLogError("[Call:Provider] Cannot start outgoing call — callLauncher not set.")
            return
        }
        callLauncher.startOutgoingCall(with: identity)
    }

    func presentIncomingCall(with identity: String) {
        guard let callLauncher else {
            DDLogError("[Call:Provider] Cannot present incoming call — callLauncher not set.")
            return
        }
        callLauncher.presentIncomingCall(with: identity)
    }

    func startGroupCall(in group: Group, intent: GroupCallUserIntent) {
        guard let callLauncher else {
            DDLogError("[Call:Provider] Cannot start group call — callLauncher not set.")
            return
        }
        callLauncher.startGroupCall(in: group, intent: intent)
    }
}
