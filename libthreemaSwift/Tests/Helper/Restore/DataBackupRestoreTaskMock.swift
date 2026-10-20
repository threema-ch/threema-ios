import libthreemaSwift
import os

public final class DataBackupRestoreTaskMock: DataBackupRestoreTaskProtocol {

    /// A response carries providers, a read response, or both, so one `response(response:)` call can record more than
    /// one of these.
    ///
    /// Note: `DataBackupRestoreResponse` itself is not `Equatable` — it holds the providers as existentials — so
    /// the parts are recorded rather than the response as a whole.
    public enum Call: Equatable, Sendable {
        case poll
        case providersResponse
        case readResponse(DataBackupRestoreReadResponse)
    }

    public struct MockExhausted: Error { }

    private struct State {
        var calls: [Call] = []
        var mockPoll: @Sendable () throws -> DataBackupRestoreLoop = { .done }
        var mockResponse: @Sendable (DataBackupRestoreResponse) throws -> Void = { _ in }
    }

    private let state = OSAllocatedUnfairLock<State>(initialState: State())

    public init() { }

    public func poll() throws -> DataBackupRestoreLoop {
        let stub: @Sendable () throws -> DataBackupRestoreLoop = state.withLock {
            $0.calls.append(.poll)
            return $0.mockPoll
        }
        return try stub()
    }

    public func response(response: DataBackupRestoreResponse) throws {
        let stub: @Sendable (DataBackupRestoreResponse) throws -> Void = state.withLock {
            if response.providers != nil {
                $0.calls.append(.providersResponse)
            }
            if let readResponse = response.readResponse {
                $0.calls.append(.readResponse(readResponse))
            }
            return $0.mockResponse
        }
        try stub(response)
    }

    public var calls: [Call] {
        state.withLock { $0.calls }
    }

    public var mockPoll: @Sendable () throws -> DataBackupRestoreLoop {
        get { state.withLock { $0.mockPoll } }
        set { state.withLock { $0.mockPoll = newValue } }
    }

    public func mockPoll(returning result: Result<[DataBackupRestoreLoop], any Error>) {
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

    public var mockResponse: @Sendable (DataBackupRestoreResponse) throws -> Void {
        get { state.withLock { $0.mockResponse } }
        set { state.withLock { $0.mockResponse = newValue } }
    }

    public func reset() {
        state.withLock { $0.calls.removeAll() }
    }
}

extension DataBackupRestoreTaskProtocol where Self == DataBackupRestoreTaskMock {
    public static var working: Self {
        let instance = DataBackupRestoreTaskMock()
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
        let instance = DataBackupRestoreTaskMock()
        instance.mockPoll(returning: .failure(DataBackupRestoreTaskError.pollError))
        return instance
    }
}
