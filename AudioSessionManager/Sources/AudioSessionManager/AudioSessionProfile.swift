import AVFoundation

/// The configuration a client needs in order to do its job.
///
/// A profile is a *request*, not a command. Holding one does not mean it has been applied: only the
/// winning claim's profile reaches a driver.
public struct AudioSessionProfile: Sendable, Equatable {
    public let category: AVAudioSession.Category
    public let mode: AVAudioSession.Mode
    public let options: AVAudioSession.CategoryOptions
    public let output: AudioSessionOutput

    /// Ask the system to mix alarms and timers into this session instead of interrupting it.
    /// Does not affect CallKit!
    public let prefersNoInterruptionsFromSystemAlerts: Bool

    /// Who calls `setActive(true)`.
    public let activation: AudioSessionActivation

    // MARK: - Lifecycle
    
    package init(
        category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions = [],
        output: AudioSessionOutput = .system,
        prefersNoInterruptionsFromSystemAlerts: Bool = false,
        activation: AudioSessionActivation = .driverOwned
    ) {
        self.category = category
        self.mode = mode
        self.options = options
        self.output = output
        self.prefersNoInterruptionsFromSystemAlerts = prefersNoInterruptionsFromSystemAlerts
        self.activation = activation
    }
}
