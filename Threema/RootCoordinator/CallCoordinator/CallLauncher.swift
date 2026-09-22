import CocoaLumberjackSwift
import Combine
import GroupCalls
import ThreemaEssentials
import ThreemaFramework
import ThreemaMacros
import UIKit

@MainActor
final class CallLauncher {
    private let voipCallStateManager: VoIPCallStateManager
    private let groupCallSingleton: GlobalGroupCallManagerSingleton
    private let windowScene: UIWindowScene

    private(set) var activeCall: CallCoordinator?

    /// Unified, observable call state for the new coordinator flow.
    ///
    /// - Note: This is *not* the source of the nav-bar call prompt. The `NavigationBarPromptHandler`
    ///   flags are owned by the engines (`CallViewController` for 1-1, `GroupCallSessionHelper` for
    ///   group) as a contract shared with the legacy flow, so the launcher must not write them.
    @Published private(set) var activity: CallActivity = .none

    var activityPublisher: AnyPublisher<CallActivity, Never> {
        $activity.eraseToAnyPublisher()
    }

    // MARK: - Init

    init(
        voipCallStateManager: VoIPCallStateManager,
        groupCallSingleton: GlobalGroupCallManagerSingleton,
        windowScene: UIWindowScene
    ) {
        self.voipCallStateManager = voipCallStateManager
        self.groupCallSingleton = groupCallSingleton
        self.windowScene = windowScene
        voipCallStateManager.onCallAnswered = { [weak self] identity in
            self?.presentIncomingCall(with: identity)
        }
        // The launcher is the persistent group call UI delegate. In-call presentation is forwarded
        // to the active `CallCoordinator`; the incoming-call banner must work between calls (when no
        // coordinator exists), so it is handled here directly.
        groupCallSingleton.uiDelegate = self
    }

    // MARK: - Public

    func startOutgoingCall(with identity: String) {
        start(.oneToOne(identity: identity, incoming: false))
    }

    func presentIncomingCall(with identity: String) {
        start(.oneToOne(identity: identity, incoming: true))
    }

    func startGroupCall(in group: Group, intent: GroupCallUserIntent) {
        start(.group(group: group, intent: intent))
    }

    // MARK: - Private

    @discardableResult
    private func start(_ callType: CallType) -> Bool {
        guard let active = activeCall else {
            DDLogNotice("[Call:Launcher] No active call, spawning new call: \(callType)")
            return spawn(callType)
        }

        if active.callType == callType {
            DDLogNotice("[Call:Launcher] Call already active for same target, presenting existing UI: \(callType)")
            active.presentCallUI()
            return true
        }

        DDLogWarn("[Call:Launcher] Cannot start \(callType), another call is already active: \(active.callType)")
        showCallActiveAlert()
        return false
    }

    @discardableResult
    private func spawn(_ callType: CallType) -> Bool {
        let coordinator = CallCoordinator(
            callType: callType,
            windowScene: windowScene,
            notificationCenter: NotificationCenter.default,
            voipCallStateManager: voipCallStateManager,
            groupCallSingleton: groupCallSingleton,
            onActivityChange: { [weak self] activity in
                self?.activity = activity
            },
            onFinished: { [weak self] in
                self?.activeCall = nil
                self?.activity = .none
            }
        )

        activeCall = coordinator
        coordinator.start()
        return true
    }

    private func showCallActiveAlert() {
        guard let owner = windowScene.keyWindow?.rootViewController else {
            return
        }

        UIAlertTemplate.showOKAlert(
            owner: owner,
            title: #localize("group_call_error_already_in_call_title"),
            message: #localize("group_call_error_already_in_call_message")
        )
    }
}

// MARK: - GroupCallManagerSingletonUIDelegate

extension CallLauncher: GroupCallManagerSingletonUIDelegate {
    func showViewController(_ viewController: GroupCallViewController) {
        guard let activeCall else {
            DDLogError("[Call:GroupCall:Launcher] Cannot show GroupCallViewController, no active call.")
            return
        }
        activeCall.showViewController(viewController)
    }

    func showAlert(for groupCallError: GroupCallErrorProtocol) {
        guard let activeCall else {
            DDLogError("[Call:GroupCall:Launcher] Cannot show group call alert, no active call.")
            return
        }
        activeCall.showAlert(for: groupCallError)
    }

    func localUserLeftGroupCall(in groupIdentity: GroupIdentity) {
        activeCall?.localUserLeftGroupCall(in: groupIdentity)
    }

    func showGroupCallFullAlert(maxParticipants: Int?, onOK: @escaping () -> Void) {
        guard let activeCall else {
            DDLogError("[Call:GroupCall:Launcher] Cannot show group call full alert, no active call.")
            return
        }
        activeCall.showGroupCallFullAlert(maxParticipants: maxParticipants, onOK: onOK)
    }

    func newBannerForStartGroupCall(
        conversationManagedObjectID: NSManagedObjectID,
        title: String,
        body: String,
        identifier: String
    ) {
        // Runs between calls (no active coordinator) — handled by the static helper directly.
        GroupCallUIHelper.newBannerForStartGroupCall(
            conversationManagedObjectID: conversationManagedObjectID,
            title: title,
            body: body,
            identifier: identifier
        )
    }
}
