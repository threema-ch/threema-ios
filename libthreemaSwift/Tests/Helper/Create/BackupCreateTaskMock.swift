import libthreemaSwift
import os

public final class BackupCreateTaskMock: BackupCreateTaskProtocol {

    public enum Call: Equatable, Sendable {
        case getFilename
        case poll
    }

    public struct MockExhausted: Error { }

    private struct State {
        var calls: [Call] = []
        var mockGetFilename: @Sendable () -> Filename = { "" }
        var mockPoll: @Sendable () throws -> BackupCreateLoop = { .done(0) }
    }

    private let state = OSAllocatedUnfairLock<State>(initialState: State())

    public init() { }

    public func poll() throws -> BackupCreateLoop {
        let stub: @Sendable () throws -> BackupCreateLoop = state.withLock {
            $0.calls.append(.poll)
            return $0.mockPoll
        }
        return try stub()
    }

    public func getFilename() -> Filename {
        let stub: @Sendable () -> Filename = state.withLock {
            $0.calls.append(.getFilename)
            return $0.mockGetFilename
        }
        return stub()
    }

    public var calls: [Call] {
        state.withLock { $0.calls }
    }

    public var mockGetFilename: @Sendable () -> Filename {
        get { state.withLock { $0.mockGetFilename } }
        set { state.withLock { $0.mockGetFilename = newValue } }
    }

    public var mockPoll: @Sendable () throws -> BackupCreateLoop {
        get { state.withLock { $0.mockPoll } }
        set { state.withLock { $0.mockPoll = newValue } }
    }

    public func mockPoll(returning result: Result<[BackupCreateLoop], any Error>) {
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

    public func reset() {
        state.withLock { $0.calls.removeAll() }
    }
}

extension BackupCreateTaskProtocol where Self == BackupCreateTaskMock {
    public static var working: Self {
        let instance = BackupCreateTaskMock()
        instance.mockPoll(
            returning: .success([
                .writeAtInstruction(count: 10),
                .writeAppendInstruction(count: 10),
                .stateUpdateInstruction(state: .contacts(20)),
                .done(20)
            ])
        )
        return instance
    }

    public static var failingOnPoll: Self {
        let instance = BackupCreateTaskMock()
        instance.mockPoll(returning: .failure(BackupCreateTaskError.pollError))
        return instance
    }
}
