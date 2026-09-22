import DataBackup
import os

public struct DataRestoreMock: DataRestoreProtocol {

    // MARK: - Public types

    public enum Call: Equatable, Sendable {
        case perform
    }

    // MARK: - Private types

    private struct State {
        var calls: [Call] = []
        var mockPerform: @Sendable () throws -> Void = { /* no-op */ }
    }

    // MARK: - Private properties

    private let state = OSAllocatedUnfairLock<State>(initialState: State())

    // MARK: - Lifecycle

    public init() { /* no-op */ }

    // MARK: - Public properties

    public var mockPerform: @Sendable () throws -> Void {
        get { state.withLock { $0.mockPerform } }
        set { state.withLock { $0.mockPerform = newValue } }
    }

    public var calls: [Call] {
        state.withLock { $0.calls }
    }

    // MARK: - Public methods

    public func reset() {
        state.withLock { $0.calls.removeAll() }
    }

    public func perform() async throws {
        let stub: @Sendable () throws -> Void = state.withLock {
            $0.calls.append(.perform)
            return $0.mockPerform
        }
        return try stub()
    }
}
