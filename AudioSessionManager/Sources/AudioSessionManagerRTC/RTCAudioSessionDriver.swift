import AudioSessionManager
import AVFoundation
import CocoaLumberjackSwift
import WebRTC

/// Drives `RTCAudioSession` for calls, under CallKit's ownership of activation.
actor RTCAudioSessionDriver: ExternallyActivatedDriver {

    private var recovery: (any AudioSessionRecovering)?

    /// Whether this driver activated the session, so `deactivate()` undoes only what it did.
    private var didActivateSession = false

    private nonisolated var session: RTCAudioSession {
        .sharedInstance()
    }

    // MARK: - Lifecycle

    init() {
        session.useManualAudio = true
    }

    // MARK: - AudioSessionDriverProtocol

    func apply(_ profile: AudioSessionProfile) async throws {
        DDLogVerbose(
            "[RTCAudioSessionDriver] Applying \(profile.category.rawValue)/\(profile.mode.rawValue)"
                + " output=\(profile.output) options=\(profile.options.rawValue)"
                + " default-to-speaker=\(profile.options.contains(.defaultToSpeaker))"
        )

        // Configure first, activate below only if this profile says the activation is ours.
        let configuration = RTCAudioSessionConfiguration()
        configuration.category = profile.category.rawValue
        configuration.mode = profile.mode.rawValue
        configuration.categoryOptions = profile.options

        RTCAudioSessionConfiguration.setWebRTC(configuration)

        session.lockForConfiguration()
        defer { session.unlockForConfiguration() }

        do {
            try session.setConfiguration(configuration)
        }
        catch {
            DDLogError("[RTCAudioSessionDriver] Setting configuration failed: \(error)")
            throw error
        }

        do {
            try session.session.setPrefersNoInterruptionsFromSystemAlerts(
                profile.prefersNoInterruptionsFromSystemAlerts
            )

            DDLogVerbose(
                "[RTCAudioSessionDriver] Alert-interruption preference asked=\(profile.prefersNoInterruptionsFromSystemAlerts) got=\(session.session.prefersNoInterruptionsFromSystemAlerts)"
            )
        }
        catch {
            DDLogWarn(
                "[RTCAudioSessionDriver] Alert-interruption preference \(profile.prefersNoInterruptionsFromSystemAlerts) failed: \(error)"
            )
        }

        // Group calls have no CallKit, so nothing else will ever activate for them.
        if profile.activation == .driverOwned {
            do {
                try session.setActive(true)
                session.isAudioEnabled = true
                didActivateSession = true
            }
            catch {
                DDLogError("[RTCAudioSessionDriver] Activating the session failed: \(error)")
                throw error
            }
        }

        do {
            switch profile.output {
            case .system, .receiver:
                // A call is always `.playAndRecord`, where no override and no `.defaultToSpeaker` already
                // means the earpiece, so there is nothing for `.receiver` to do here.
                try session.overrideOutputAudioPort(.none)
            case .speaker:
                try session.overrideOutputAudioPort(.speaker)
            }
        }
        catch {
            DDLogError("[RTCAudioSessionDriver] Overriding output to \(profile.output) failed: \(error)")
            throw error
        }
    }

    /// Adds what only this driver can see.
    func diagnostics() async -> String {
        let avSession = session.session
        let route = avSession.currentRoute
        let inputs = route.inputs.map(\.portType.rawValue).joined(separator: "+")
        let outputs = route.outputs.map(\.portType.rawValue).joined(separator: "+")

        return "category=\(avSession.category.rawValue)" +
            ", mode=\(avSession.mode.rawValue)" +
            ", default-to-speaker=\(avSession.categoryOptions.contains(.defaultToSpeaker))" +
            ", no-alerts=\(avSession.prefersNoInterruptionsFromSystemAlerts)" +
            ", rtc-active=\(session.isActive)" +
            ", manual-audio=\(session.useManualAudio)" +
            ", audio-enabled=\(session.isAudioEnabled)" +
            ", in=\(inputs.isEmpty ? "none" : inputs)" +
            ", out=\(outputs.isEmpty ? "none" : outputs)"
    }

    /// Reads the underlying `AVAudioSession`, as the alert-interruption preference above does: route is not
    /// state `RTCAudioSession` tracks, so there is nothing to desynchronise by reading it here.
    func currentRoute() async -> AudioSessionRouteSnapshot {
        let avSession = session.session

        return AudioSessionRouteSnapshot(
            outputs: avSession.currentRoute.outputs.map(\.portType),
            hasBluetoothInput: avSession.availableInputs?
                .contains { AudioSessionRouteSnapshot.bluetoothInputPorts.contains($0.portType) } ?? false
        )
    }

    /// Stop WebRTC's audio processing, and hand the session back if this driver took it.
    func deactivate() async throws {
        DDLogVerbose("[RTCAudioSessionDriver] Disabling audio.")
        session.isAudioEnabled = false

        guard didActivateSession else {
            return
        }
        didActivateSession = false

        session.lockForConfiguration()
        defer { session.unlockForConfiguration() }

        do {
            try session.setActive(false)
        }
        catch {
            DDLogError("[RTCAudioSessionDriver] Deactivating the session failed: \(error)")
            throw error
        }
    }

    /// Recovery cannot be done by configuring
    func recoverFromInterruption(restoring profile: AudioSessionProfile) async throws {
        guard let recovery else {
            DDLogError(
                "[RTCAudioSessionDriver] No recovery hook, so the input route stays broken until the call is remade"
            )
            return
        }

        DDLogVerbose("[RTCAudioSessionDriver] Requesting CallKit reactivation after interruption.")
        await recovery.requestAudioSessionReactivation()
    }

    // MARK: - ExternallyActivatedDriver

    func setRecovery(_ recovery: (any AudioSessionRecovering)?) {
        self.recovery = recovery
    }

    /// Forward `provider(_:didActivate:)`.
    /// Note:`nonisolated` since hopping onto the actor would let `provider(_:didActivate:)` return before WebRTC had
    /// observed the activation. `RTCSession` has its own lock, so we are good
    nonisolated func sessionDidActivate(_ session: AVAudioSession) {
        DDLogVerbose("[RTCAudioSessionDriver] CallKit activated the session.")

        // The order matters: WebRTC has to observe the activation before anything else touches the session.
        self.session.audioSessionDidActivate(session)
        self.session.isAudioEnabled = true
    }

    /// Forward `provider(_:didDeactivate:)`.
    /// Note:`nonisolated` for the reasons on `sessionDidActivate(_:)`.
    nonisolated func sessionDidDeactivate(_ session: AVAudioSession) {
        DDLogVerbose("[RTCAudioSessionDriver] CallKit deactivated the session.")

        self.session.isAudioEnabled = false
        self.session.audioSessionDidDeactivate(session)
    }
}
