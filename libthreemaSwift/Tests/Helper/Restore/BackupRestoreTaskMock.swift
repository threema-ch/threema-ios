import libthreemaSwift
import os

public final class BackupRestoreTaskMock: BackupRestoreTaskProtocol {

    public enum Call: Equatable, Sendable {
        case addProviders
        case poll
        case response(readResponse: BackupRestoreResponse)
    }

    public struct MockExhausted: Error { }

    private struct State {
        var calls: [Call] = []
        var mockAddProviders: @Sendable (BackupRestoreProviders) throws -> Void = { _ in }
        var mockPoll: @Sendable () throws -> BackupRestoreLoop = { .done }
        var mockResponseReadResponse: @Sendable (BackupRestoreResponse) throws -> UInt64 = { _ in 0 }
    }

    private let state = OSAllocatedUnfairLock<State>(initialState: State())

    public init() { }

    public func addProviders(providers: BackupRestoreProviders) throws {
        let stub: @Sendable (BackupRestoreProviders) throws -> Void = state.withLock {
            $0.calls.append(.addProviders)
            return $0.mockAddProviders
        }
        try stub(providers)
    }

    public func poll() throws -> BackupRestoreLoop {
        let stub: @Sendable () throws -> BackupRestoreLoop = state.withLock {
            $0.calls.append(.poll)
            return $0.mockPoll
        }
        return try stub()
    }

    public func response(readResponse: BackupRestoreResponse) throws -> UInt64 {
        let stub: @Sendable (BackupRestoreResponse) throws -> UInt64 = state.withLock {
            $0.calls.append(.response(readResponse: readResponse))
            return $0.mockResponseReadResponse
        }
        return try stub(readResponse)
    }

    public var calls: [Call] {
        state.withLock { $0.calls }
    }

    public var mockAddProviders: @Sendable (BackupRestoreProviders) throws -> Void {
        get { state.withLock { $0.mockAddProviders } }
        set { state.withLock { $0.mockAddProviders = newValue } }
    }

    public var mockPoll: @Sendable () throws -> BackupRestoreLoop {
        get { state.withLock { $0.mockPoll } }
        set { state.withLock { $0.mockPoll = newValue } }
    }

    public func mockPoll(returning result: Result<[BackupRestoreLoop], any Error>) {
        switch result {
        case let .success(values):
            let index = OSAllocatedUnfairLock(initialState: 0)
            mockPoll = {
                try index.withLock { i in
                    guard i < values.count else {
                        throw MockExhausted()
                    }
                    defer { i += 1 }
                    return values[i]
                }
            }
        case let .failure(error):
            mockPoll = { throw error }
        }
    }

    public var mockResponseReadResponse: @Sendable (BackupRestoreResponse) throws -> UInt64 {
        get { state.withLock { $0.mockResponseReadResponse } }
        set { state.withLock { $0.mockResponseReadResponse = newValue } }
    }

    public func reset() {
        state.withLock { $0.calls.removeAll() }
    }
}

extension BackupRestoreTaskProtocol where Self == BackupRestoreTaskMock {
    public static var working: Self {
        let instance = BackupRestoreTaskMock()
        instance.mockPoll(
            returning: .success([
                .identityDataInstruction,
                .stateUpdateInstruction(.contacts),
                .localReadInstruction(offset: 0, length: 10),
                .done
            ])
        )
        return instance
    }

    public static var failingOnPoll: Self {
        let instance = BackupRestoreTaskMock()
        instance.mockPoll(returning: .failure(BackupRestoreTaskError.pollError))
        return instance
    }
}
