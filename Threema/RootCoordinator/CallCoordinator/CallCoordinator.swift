import CocoaLumberjackSwift
import Combine
import GroupCalls
import ThreemaEssentials
import ThreemaFramework
import ThreemaMacros
import UIKit

@MainActor
final class CallCoordinator {
    let callType: CallType

    private let notificationCenter: any NotificationCenterProtocol
    private let voipCallStateManager: VoIPCallStateManager
    private let groupCallSingleton: GlobalGroupCallManagerSingleton
    private let windowScene: UIWindowScene
    private let onActivityChange: ((CallActivity) -> Void)?
    private let onFinished: (() -> Void)?

    private var callWindow: CallWindow?
    private let rootViewController = UIViewController()
    private var subscriptions = Set<AnyCancellable>()
    private var appActivationSubscription: AnyCancellable?
    private var observers: [any NSObjectProtocol] = []

    /// Set while we wait for the group call view to be dismissed before finishing
    private var isFinishing = false

    // MARK: - Init

    init(
        callType: CallType,
        windowScene: UIWindowScene,
        notificationCenter: any NotificationCenterProtocol,
        voipCallStateManager: VoIPCallStateManager,
        groupCallSingleton: GlobalGroupCallManagerSingleton,
        onActivityChange: ((CallActivity) -> Void)?,
        onFinished: (() -> Void)?
    ) {
        self.callType = callType
        self.windowScene = windowScene
        self.notificationCenter = notificationCenter
        self.voipCallStateManager = voipCallStateManager
        self.groupCallSingleton = groupCallSingleton
        self.onActivityChange = onActivityChange
        self.onFinished = onFinished
    }

    deinit {
        observers.forEach { notificationCenter.removeObserver($0) }
        observers.removeAll()
    }
    
    // MARK: - Lifecycle

    func start() {
        createCallWindow()

        switch callType {
        case let .oneToOne(identity, incoming):
            // An incoming 1-1 call is only spawned once it has been answered (via CallKit), so it is
            // already active here. An outgoing call starts ringing until the remote picks up, then
            // transitions to `.active` via `onCallConnected`.
            reportActivity(.oneToOne(identity: identity, state: incoming ? .active : .ringingOutgoing))
            // Present the 1-1 call view on this call's `CallWindow` (not the key window), so it lands
            // there even when returning from minimize via the nav prompt (which bypasses the coordinator).
            voipCallStateManager.callViewPresenterProvider = { [weak self] in
                self?.callWindow?.isHidden = false
                self?.callWindow?.makeKeyAndVisible()
                return self?.rootViewController
            }
            voipCallStateManager.onCallViewHidden = { [weak self] in
                self?.hideCallWindow()
            }
            voipCallStateManager.onCallFinished = { [weak self] in
                self?.finish()
            }
            if !incoming {
                voipCallStateManager.onCallConnected = { [weak self] in
                    self?.reportActivity(.oneToOne(identity: identity, state: .active))
                }
                voipCallStateManager.startCall(callee: identity)
            }
        case let .group(group, intent):
            reportActivity(.group(groupID: group.groupIdentity, state: .connecting))
            observeGroupCall(groupIdentity: group.groupIdentity)
            do {
                try groupCallSingleton.startGroupCall(in: group, intent: intent)
            }
            catch {
                hideCallWindow()
                onFinished?()
            }
        }

        observeAppActivation()
        observeShowConversationNotification()
    }

    // MARK: - Public

    func presentCallUI() {
        // The call window sits above the app at `WindowLevel.call` over an empty root view controller. It may only be
        // shown if a call view is presented on it, otherwise it swallows all touches without showing anything.
        guard rootViewController.presentedViewController == nil else {
            callWindow?.isHidden = false
            callWindow?.makeKeyAndVisible()
            return
        }

        // Both presentation paths show the window themselves when they actually present something
        if case .oneToOne = callType {
            voipCallStateManager.presentCallViewController()
        }
        else if case .group = callType {
            groupCallSingleton.showGroupCallViewController()
        }
    }

    /// The local user is no longer participating in the group call of the given group
    ///
    /// The call itself might still be running with other participants. We only own a call as long as the local user
    /// participates in it, from here on it is joined again like any other call.
    func localUserLeftGroupCall(in groupIdentity: GroupIdentity) {
        guard case let .group(group, _) = callType, group.groupIdentity == groupIdentity else {
            return
        }

        DDLogNotice("[Call:GroupCall:Coordinator] Local user left the group call, finishing.")

        finish()
    }

    // MARK: - Private

    private func finish() {
        // A dismissal is in flight, its completion finishes us
        guard !isFinishing else {
            return
        }

        // For group calls the call view is dismissed as part of leaving. Tearing down the window underneath a dismissal
        // in flight cuts it short and skips the view controller's appearance callbacks, which restore the idle timer.
        // Thus we let the dismissal complete and finish afterwards.
        if case .group = callType, rootViewController.presentedViewController != nil {
            isFinishing = true
            rootViewController.dismiss(animated: true) { [weak self] in
                self?.isFinishing = false
                self?.finish()
            }
            return
        }

        subscriptions.removeAll()
        appActivationSubscription?.cancel()
        appActivationSubscription = nil
        callWindow?.isHidden = true
        callWindow?.resignKey()
        callWindow = nil
        onActivityChange?(.none)
        onFinished?()
    }
    
    private func observeShowConversationNotification() {
        observers.append(notificationCenter.addObserver(
            forName: Notification.Name(kNotificationShowConversation),
            object: nil,
            queue: .main,
            using: { [weak self] _ in
                Task { @MainActor in
                    self?.hideCallWindow()
                }
            }
        ))
    }

    // MARK: - Window Management

    /// Creates the call window without showing it.
    ///
    /// It must stay hidden until something is presented on it, otherwise it swallows all touches while showing
    /// nothing. Both presentation paths unhide and key the window when they actually present the call view.
    private func createCallWindow() {
        let window = CallWindow(windowScene: windowScene)
        window.rootViewController = rootViewController
        window.isHidden = true
        callWindow = window
    }

    private func hideCallWindow() {
        callWindow?.resignKey()
        callWindow?.isHidden = true
    }

    /// If the coordinator was created while the app was in the background (e.g. lock-screen
    /// accept), `makeKeyAndVisible` and `presentCallView` had no effect.
    ///
    /// Keeps observing `didBecomeActive` until the call view is actually presented. A single
    /// `.first()` isn't enough because biometric auth (Face ID) makes the app `.inactive`,
    /// causing `showCallViewIfActive` to drop the presentation on the first attempt.
    private func observeAppActivation() {
        appActivationSubscription = NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, callWindow != nil else {
                    return
                }
                // Already presented — stop observing.
                guard rootViewController.presentedViewController == nil else {
                    self.appActivationSubscription?.cancel()
                    self.appActivationSubscription = nil
                    return
                }
                presentCallUI()
            }
    }

    private func reportActivity(_ activity: CallActivity) {
        onActivityChange?(activity)
    }

    private func observeGroupCall(groupIdentity: GroupIdentity) {
        groupCallSingleton.globalGroupCallObserver.publisher.pub
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                guard let self, update.groupIdentity == groupIdentity else {
                    return
                }

                if update.joinState == .notJoined, update.hideComponent {
                    self.finish()
                    return
                }

                switch update.joinState {
                case .joining:
                    self.reportActivity(.group(groupID: groupIdentity, state: .connecting))
                case .joined:
                    self.reportActivity(.group(groupID: groupIdentity, state: .active))
                case .notJoined:
                    break
                }
            }
            .store(in: &subscriptions)
    }
}

// MARK: - GroupCallManagerSingletonUIDelegate

extension CallCoordinator: GroupCallManagerSingletonUIDelegate {
    func showViewController(_ viewController: GroupCallViewController) {
        guard SharedAppProvider.alertViewShown == nil else {
            DDLogError(
                "[Call:GroupCall:Coordinator] Do not show GroupCallViewController because an alert is being presented."
            )
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            // Unhide and re-key the window when (re)showing the call view — it may have been hidden while minimized.
            self?.callWindow?.isHidden = false
            self?.callWindow?.makeKeyAndVisible()
            viewController.onDismiss = { [weak self] in
                self?.hideCallWindow()
            }
            self?.rootViewController.present(viewController, animated: true)
        }
    }

    func showAlert(for groupCallError: GroupCallErrorProtocol) {
        guard let owner = callWindow?.rootViewController else {
            DDLogError("[Call:GroupCall:Coordinator] `CallWindow` rootViewController not available.")
            return
        }

        UIAlertTemplate.showOKAlert(
            owner: owner,
            title: BundleUtil.localizedString(forKey: groupCallError.alertTitleKey),
            message: BundleUtil.localizedString(forKey: groupCallError.alertMessageKey)
        )
    }

    func showGroupCallFullAlert(maxParticipants: Int?, onOK: @escaping () -> Void) {
        let title = #localize("group_call_alert_full_title")
        let message =
            if let maxParticipants {
                String.localizedStringWithFormat(#localize("group_call_alert_full_message_count"), maxParticipants)
            }
            else {
                #localize("group_call_alert_full_message")
            }

        guard let owner = callWindow?.rootViewController else {
            DDLogError("[Call:GroupCall:Coordinator] `CallWindow` rootViewController not available.")
            return
        }

        UIAlertTemplate.showOKAlert(
            owner: owner,
            title: title,
            message: message
        ) { _ in
            onOK()
        }
    }

    func newBannerForStartGroupCall(
        conversationManagedObjectID: NSManagedObjectID,
        title: String,
        body: String,
        identifier: String
    ) {
        // Runs between calls — delegates to the static helper in GroupCallUIHelper
        GroupCallUIHelper.newBannerForStartGroupCall(
            conversationManagedObjectID: conversationManagedObjectID,
            title: title,
            body: body,
            identifier: identifier
        )
    }
}
