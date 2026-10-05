import CocoaLumberjackSwift
import Foundation
import ThreemaFramework

protocol VoIPCallReporting: AnyObject {
    func newIncomingCallFromBackground(
        with callID: VoIPCallID,
        callPartnerIdentity: String,
        callPartnerName: String?,
        ringtoneSound: String,
        fromPush: Bool,
        completion: @escaping (@escaping () -> Void) -> Void
    )

    /// Hangup of the ringing call, forwarded by the Notification Extension. Hands back the task that ends it.
    func ringingCallHungUpFromBackground(
        with callID: VoIPCallID,
        callPartnerIdentity: String,
        callPartnerName: String?,
        completion: @escaping (@escaping () -> Void) -> Void
    )

    /// Report and immediately cancel a call. Needed for any VoIP push we cannot interpret, because
    /// `CXProvider.reportNewIncomingCall` must be called for *every* VoIP push.
    func startAndCancelCall(from localizedName: String, completion: @escaping () -> Void)
}

// MARK: - VoIPCallStateManager + VoIPCallReporting

extension VoIPCallStateManager: VoIPCallReporting { }

/// Handles an incoming VoIP push: reports the call to CallKit right away, then connects it as soon
/// as the business layer allows.
@MainActor
final class VoIPPushHandler {

    private let callReporter: () -> any VoIPCallReporting
    private let markAppActive: () -> Void
    private let isLaunchSequenceRunning: @MainActor () -> Bool
    private let bringUpBusinessLayer: @MainActor () async -> Bool
    private let activationDelay: Duration

    private var isBusinessReady = false
    private var pendingTasks: [() -> Void] = []

    /// Not private so tests can await a scheduled bring-up instead of polling
    private(set) var headlessActivation: Task<Void, Never>?

    /// Every dependency is resolved when a push arrives, not when this is created: it is
    /// instantiated together with the app delegate, long before `UserSettings` or the CallKit
    /// provider should be touched.
    init(
        callReporter: @escaping @autoclosure () -> any VoIPCallReporting = VoIPCallStateManager.shared,
        markAppActive: @escaping () -> Void = { AppGroup.setMeActiveUnlessIPC() },
        isLaunchSequenceRunning: @MainActor @escaping () -> Bool = { SceneDelegate.current?.rootCoordinator != nil },
        bringUpBusinessLayer: @MainActor @escaping () async -> Bool = { await HeadlessBusinessBootstrap.run() },
        activationDelay: Duration = .seconds(1)
    ) {
        self.callReporter = callReporter
        self.markAppActive = markAppActive
        self.isLaunchSequenceRunning = isLaunchSequenceRunning
        self.bringUpBusinessLayer = bringUpBusinessLayer
        self.activationDelay = activationDelay
    }

    // MARK: - Incoming push

    /// Report the call contained in `dictionaryPayload` to CallKit.
    ///
    /// Must be called synchronously from the `PKPushRegistryDelegate` callback. Never returns without
    /// reporting a call.
    ///
    /// - Parameters:
    ///   - dictionaryPayload: `PKPushPayload.dictionaryPayload` as delivered by PushKit
    ///   - completion: PushKit completion handler, called once the call is reported
    func report(dictionaryPayload rawPayload: [AnyHashable: Any], completion: @escaping () -> Void) {
        markAppActive()

        if let dictionaryPayload = rawPayload as? [String: String],
           let identity = dictionaryPayload[Constants.notificationExtensionHangup],
           let callIDString = dictionaryPayload[Constants.notificationExtensionCallID],
           let callIDRawValue = UInt32(callIDString) {
            let callID = VoIPCallID(callID: callIDRawValue)
            DDLogNotice(
                "[Call:1to1:VoIPPushHandler] [cid=\(callID)] Hangup of the ringing call reported from push kit notification"
            )

            callReporter().ringingCallHungUpFromBackground(
                with: callID,
                callPartnerIdentity: identity,
                callPartnerName: dictionaryPayload[Constants.notificationExtensionCallerName]
            ) { [weak self] task in
                MainActor.assumeIsolated {
                    self?.runWhenBusinessReady(task)
                }

                completion()
            }
            return
        }

        guard
            let dictionaryPayload = rawPayload as? [String: String],
            let identity = dictionaryPayload[Constants.notificationExtensionOffer],
            let displayName = dictionaryPayload[Constants.notificationExtensionCallerName],
            let ringtoneSound = dictionaryPayload[Constants.notificationExtensionRingtoneSoundName],
            let callIDString = dictionaryPayload[Constants.notificationExtensionCallID],
            let callIDRawValue = UInt32(callIDString)
        else {
            DDLogWarn(
                "[Call:1to1:VoIPPushHandler] VoIP push payload could not be parsed. Reporting and cancelling call"
            )

            callReporter().startAndCancelCall(
                from: TargetManager.appName,
                completion: completion
            )
            return
        }

        // Report the call now, connect it once business is ready
        let callID = VoIPCallID(callID: callIDRawValue)
        DDLogNotice(
            "[Call:1to1:VoIPPushHandler] [cid=\(callID)] Call reported from push kit notification. Reporting call"
        )

        callReporter().newIncomingCallFromBackground(
            with: callID,
            callPartnerIdentity: identity,
            callPartnerName: displayName,
            ringtoneSound: ringtoneSound,
            fromPush: true
        ) { [weak self] task in
            // CallKit delivers this on its provider queue, which is the main queue (the provider's
            // delegate is set without a queue in `VoIPCallKitManager`)
            MainActor.assumeIsolated {
                self?.runWhenBusinessReady(task)
            }

            completion()
        }
    }

    // MARK: - Business readiness

    func businessDidBecomeReady() {
        isBusinessReady = true

        headlessActivation?.cancel()
        headlessActivation = nil

        let queued = pendingTasks
        pendingTasks.removeAll()
        for task in queued {
            task()
        }
    }

    // MARK: - Private

    private func runWhenBusinessReady(_ task: @escaping () -> Void) {
        guard !isBusinessReady else {
            task()
            return
        }

        pendingTasks.append(task)
        scheduleHeadlessActivationIfNeeded()
    }

    private func scheduleHeadlessActivationIfNeeded() {
        guard headlessActivation == nil else {
            return
        }

        headlessActivation = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            // Grace period for a scene that is connecting right now: it owns the bring-up. A single
            // check afterwards is enough, because `SceneDelegate.rootCoordinator` is assigned once
            // and never cleared — a launch sequence cannot start later or stop again.
            try? await Task.sleep(for: activationDelay)

            guard !Task.isCancelled, !isBusinessReady else {
                return
            }

            guard !isLaunchSequenceRunning() else {
                DDLogNotice("[Call:1to1:VoIPPushHandler] A launch sequence is running, leaving the bring-up to it")
                return
            }

            DDLogNotice("[Call:1to1:VoIPPushHandler] No launch sequence ran, bringing up business for call")

            let didBringUp = await bringUpBusinessLayer()
            headlessActivation = nil

            guard didBringUp else {
                DDLogError("[Call:1to1:VoIPPushHandler] Bring-up failed, waiting for a launch sequence instead")
                return
            }

            businessDidBecomeReady()
        }
    }
}
