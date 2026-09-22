import AVFoundation

/// Where the session's audio is coming out right now, and whether a Bluetooth input is available to it.
public struct AudioSessionRouteSnapshot: Sendable, Equatable {

    /// The ports audio is currently coming out of.
    public let outputs: [AVAudioSession.Port]

    /// Whether a Bluetooth device is available as an input.
    public let hasBluetoothInput: Bool

    // MARK: - Lifecycle

    /// `package`: only a driver produces one of these, and only from a real session.
    package init(outputs: [AVAudioSession.Port], hasBluetoothInput: Bool) {
        self.outputs = outputs
        self.hasBluetoothInput = hasBluetoothInput
    }

    // MARK: - Package properties

    /// Input ports that count as Bluetooth, in one place so both drivers answer the same question.
    package static let bluetoothInputPorts: Set<AVAudioSession.Port> = [
        .bluetoothA2DP,
        .bluetoothHFP,
        .bluetoothLE,
    ]
}
