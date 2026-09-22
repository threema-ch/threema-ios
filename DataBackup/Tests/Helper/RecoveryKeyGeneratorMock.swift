import DataBackup
import os

public struct RecoveryKeyGeneratorMock: RecoveryKeyGeneratorProtocol {

    // MARK: - Public types

    public enum Call: Equatable, Sendable {
        case generate
    }

    // MARK: - Private types

    private struct State {
        var calls: [Call] = []
        var mockGenerate: @Sendable () throws -> String = {
            String(repeating: "A1B2C3D4", count: 8)
        }
    }

    // MARK: - Private properties

    private let state = OSAllocatedUnfairLock<State>(initialState: State())

    // MARK: - Lifecycle

    public init() { /* no-op */ }

    // MARK: - Public properties

    public var mockGenerate: @Sendable () throws -> String {
        get { state.withLock { $0.mockGenerate } }
        set { state.withLock { $0.mockGenerate = newValue } }
    }

    public var calls: [Call] {
        state.withLock { $0.calls }
    }

    // MARK: - Public methods

    public func reset() {
        state.withLock { $0.calls.removeAll() }
    }

    public func generate() throws -> String {
        let stub: @Sendable () throws -> String = state.withLock {
            $0.calls.append(.generate)
            return $0.mockGenerate
        }
        return try stub()
    }
}

extension RecoveryKeyGeneratorProtocol where Self == RecoveryKeyGeneratorMock {
    public static var mock: Self {
        RecoveryKeyGeneratorMock()
    }
}
