import DataBackup
import libthreemaSwift
import libthreemaSwiftTestHelper
import os

public final class DataRestoreDelegateMock: DataRestoreDelegate {

    public enum Call: Equatable, Sendable {
        case didReceiveIdentityData(IdentityData)
        case didReceiveStateUpdate(DataBackupRestoreStateUpdate)
    }

    private struct State {
        var calls: [Call] = []
        var mockDidReceiveIdentityData: @Sendable (DataRestore, IdentityData) throws -> Void = { _, _ in /* no-op */ }
        var mockDidReceiveStateUpdate: @Sendable (DataRestore, DataBackupRestoreStateUpdate) -> Void = { _, _ in /* no-op */ }
    }

    private let state = OSAllocatedUnfairLock<State>(initialState: State())

    public init() { /* no-op */ }

    public func dataRestore(_ dataRestore: DataRestore, didReceiveIdentityData data: IdentityData) throws {
        let stub: @Sendable (DataRestore, IdentityData) throws -> Void = state.withLock {
            $0.calls.append(.didReceiveIdentityData(data))
            return $0.mockDidReceiveIdentityData
        }
        try stub(dataRestore, data)
    }

    public func dataRestore(_ dataRestore: DataRestore, didReceiveStateUpdate update: DataBackupRestoreStateUpdate) {
        let stub: @Sendable (DataRestore, DataBackupRestoreStateUpdate) -> Void = state.withLock {
            $0.calls.append(.didReceiveStateUpdate(update))
            return $0.mockDidReceiveStateUpdate
        }
        stub(dataRestore, update)
    }

    public var calls: [Call] {
        state.withLock { $0.calls }
    }

    public var mockDidReceiveIdentityData: @Sendable (DataRestore, IdentityData) throws -> Void {
        get { state.withLock { $0.mockDidReceiveIdentityData } }
        set { state.withLock { $0.mockDidReceiveIdentityData = newValue } }
    }

    public var mockDidReceiveStateUpdate: @Sendable (DataRestore, DataBackupRestoreStateUpdate) -> Void {
        get { state.withLock { $0.mockDidReceiveStateUpdate } }
        set { state.withLock { $0.mockDidReceiveStateUpdate = newValue } }
    }

    public func reset() {
        state.withLock { $0.calls.removeAll() }
    }
}

extension DataRestoreDelegate where Self == DataRestoreDelegateMock {
    public static var working: Self {
        let instance = DataRestoreDelegateMock()
        instance.mockDidReceiveIdentityData = { dataRestore, _ in
            try dataRestore.addProviders(.mock)
        }
        return instance
    }
}
