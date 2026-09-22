import DataBackup
import Foundation
import os

/// In-memory `BackupEncryptionKeyServiceProtocol` for tests.
///
/// Records the calls made to it and lets each mutating operation be stubbed. The current key can be
/// set directly to drive a system under test into a specific state.
public final class BackupEncryptionKeyServiceMock: BackupEncryptionKeyServiceProtocol {

    // MARK: - Public types

    public enum Call: Equatable, Sendable {
        case renewKey
        case deleteKey
        case markKeyAsDefault
    }

    // MARK: - Private types

    private struct State {
        var currentKey: BackupEncryptionKey
        var calls: [Call] = []
        var mockRenewKey: @Sendable () throws -> Void = { /* no-op */ }
        var mockDeleteKey: @Sendable () throws -> Void = { /* no-op */ }
        var mockMarkKeyAsDefault: @Sendable () throws -> Void = { /* no-op */ }
    }

    // MARK: - Private properties

    private let state: OSAllocatedUnfairLock<State>

    // MARK: - Lifecycle

    public init(currentKey: BackupEncryptionKey = .none) {
        state = OSAllocatedUnfairLock(initialState: State(currentKey: currentKey))
    }

    // MARK: - Public properties

    public var currentKey: BackupEncryptionKey {
        get { state.withLock { $0.currentKey } }
        set { state.withLock { $0.currentKey = newValue } }
    }

    public var calls: [Call] {
        state.withLock { $0.calls }
    }

    public var mockRenewKey: @Sendable () throws -> Void {
        get { state.withLock { $0.mockRenewKey } }
        set { state.withLock { $0.mockRenewKey = newValue } }
    }

    public var mockDeleteKey: @Sendable () throws -> Void {
        get { state.withLock { $0.mockDeleteKey } }
        set { state.withLock { $0.mockDeleteKey = newValue } }
    }

    public var mockMarkKeyAsDefault: @Sendable () throws -> Void {
        get { state.withLock { $0.mockMarkKeyAsDefault } }
        set { state.withLock { $0.mockMarkKeyAsDefault = newValue } }
    }

    // MARK: - Public methods

    public func reset() {
        state.withLock { $0.calls.removeAll() }
    }

    public func renewKey() throws {
        let stub: @Sendable () throws -> Void = state.withLock {
            $0.calls.append(.renewKey)
            return $0.mockRenewKey
        }
        try stub()
    }

    public func deleteKey() throws {
        let stub: @Sendable () throws -> Void = state.withLock {
            $0.calls.append(.deleteKey)
            return $0.mockDeleteKey
        }
        try stub()
    }

    public func markKeyAsDefault() throws {
        let stub: @Sendable () throws -> Void = state.withLock {
            $0.calls.append(.markKeyAsDefault)
            return $0.mockMarkKeyAsDefault
        }
        try stub()
    }
}

extension BackupEncryptionKeyServiceProtocol where Self == BackupEncryptionKeyServiceMock {
    public static var mock: Self {
        BackupEncryptionKeyServiceMock()
    }
}
