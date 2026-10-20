import libthreemaSwift
import os

public final class DataBackupCreateTaskMock: DataBackupCreateTaskProtocol {

    public enum Call: Equatable, Sendable {
        case getFilename
        case poll
    }

    public struct MockExhausted: Error { }

    private struct State {
        var calls: [Call] = []
        var mockGetFilename: @Sendable () -> String = { "" }
        var mockPoll: @Sendable () throws -> DataBackupCreateLoop = { .done }
    }

    private let state = OSAllocatedUnfairLock<State>(initialState: State())

    public init() { }

    public func poll() throws -> DataBackupCreateLoop {
        let stub: @Sendable () throws -> DataBackupCreateLoop = state.withLock {
            $0.calls.append(.poll)
            return $0.mockPoll
        }
        return try stub()
    }

    public func getFilename() -> String {
        let stub: @Sendable () -> String = state.withLock {
            $0.calls.append(.getFilename)
            return $0.mockGetFilename
        }
        return stub()
    }

    public var calls: [Call] {
        state.withLock { $0.calls }
    }

    public var mockGetFilename: @Sendable () -> String {
        get { state.withLock { $0.mockGetFilename } }
        set { state.withLock { $0.mockGetFilename = newValue } }
    }

    public var mockPoll: @Sendable () throws -> DataBackupCreateLoop {
        get { state.withLock { $0.mockPoll } }
        set { state.withLock { $0.mockPoll = newValue } }
    }

    public func mockPoll(returning result: Result<[DataBackupCreateLoop], any Error>) {
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

extension DataBackupCreateTaskProtocol where Self == DataBackupCreateTaskMock {
    public static var working: Self {
        let instance = DataBackupCreateTaskMock()
        instance.mockPoll(
            returning: .success([
                .writeAtInstruction(count: 10),
                .writeAppendInstruction(count: 10),
                .stateUpdateInstruction(state: .contacts),
                .done
            ])
        )
        return instance
    }

    public static var failingOnPoll: Self {
        let instance = DataBackupCreateTaskMock()
        instance.mockPoll(returning: .failure(DataBackupCreateTaskError.pollError))
        return instance
    }
}
