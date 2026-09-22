import AVFoundation
import CocoaLumberjackSwift

/// Drives `AVAudioSession` directly for non-call related profiles.
actor AVAudioSessionDriver: AudioSessionDriverProtocol {

    /// Resolved per access rather than stored, so no non-`Sendable` reference is held as actor state.
    private var session: AVAudioSession {
        .sharedInstance()
    }

    // MARK: - Lifecycle
    
    init() {
        // no-op
    }

    // MARK: - Internal functions
    
    func apply(_ profile: AudioSessionProfile) async throws {
        DDLogVerbose(
            "[AVAudioSessionDriver] Applying \(profile.category.rawValue)/\(profile.mode.rawValue) output=\(profile.output)"
        )

        do {
            try session.setCategory(profile.category, mode: profile.mode, options: profile.options)
        }
        catch {
            DDLogError("[AVAudioSessionDriver] Setting category failed: \(error)")
            throw error
        }
        
        applyInterruptionPreference(profile.prefersNoInterruptionsFromSystemAlerts)
        
        do {
            try session.setActive(true)
        }
        catch {
            DDLogError("[AVAudioSessionDriver] Failed to activate: \(error)")
            throw error
        }

        // Explicitly override after the category change, so the route is asserted against the
        // configuration the client asked for rather than the previous one.
        do {
            switch profile.output {
            case .system, .receiver:
                try session.overrideOutputAudioPort(.none)
                
            case .speaker:
                try session.overrideOutputAudioPort(.speaker)
            }
        }
        catch {
            DDLogError("[AVAudioSessionDriver] Failed overriding output for output \(profile.output): \(error)")
            throw error
        }
    }

    func diagnostics() async -> String {
        let route = session.currentRoute
        let inputs = route.inputs.map(\.portType.rawValue).joined(separator: "+")
        let outputs = route.outputs.map(\.portType.rawValue).joined(separator: "+")

        return "category=\(session.category.rawValue)" +
            ", mode=\(session.mode.rawValue)" +
            ", no-alerts=\(session.prefersNoInterruptionsFromSystemAlerts)" +
            ", in=\(inputs.isEmpty ? "none" : inputs)" +
            ", out=\(outputs.isEmpty ? "none" : outputs)"
    }

    func currentRoute() async -> AudioSessionRouteSnapshot {
        AudioSessionRouteSnapshot(
            outputs: session.currentRoute.outputs.map(\.portType),
            hasBluetoothInput: session.availableInputs?
                .contains { AudioSessionRouteSnapshot.bluetoothInputPorts.contains($0.portType) } ?? false
        )
    }

    func deactivate() async throws {
        DDLogVerbose("[AVAudioSessionDriver] Deactivating.")
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        }
        catch {
            DDLogError("[AVAudioSessionDriver] Failed to deactivate: \(error)")
            throw error
        }
    }
    
    func recoverFromInterruption(restoring profile: AudioSessionProfile) async throws {
        DDLogVerbose("[AVAudioSessionDriver] Recovering from interruption.")
        
        do {
            try await apply(profile)
        }
        catch {
            DDLogError("[AVAudioSessionDriver] Recovering from interruption failed: \(error)")
            throw error
        }
    }
    
    // MARK: - Private functions
    
    /// Set before activating, so the preference is in force for the session the client is about to use.
    private func applyInterruptionPreference(_ prefersNoInterruptions: Bool) {
        do {
            try session.setPrefersNoInterruptionsFromSystemAlerts(prefersNoInterruptions)
        }
        catch {
            /// Failures are logged, not thrown, so the session is still configured if the system refuses.
            DDLogWarn(
                "[AVAudioSessionDriver] Alert-interruption preference \(prefersNoInterruptions) failed: \(error)"
            )
        }
    }
}
