import libthreemaSwift

/// A snapshot of an in-flight backup creation.
public struct DataBackupProgress: Equatable, Hashable, Sendable {

    // MARK: - Public types

    /// The phases a backup creation moves through, in the order they are reported in.
    public enum Phase: Int, CaseIterable, Comparable, Sendable {
        case initializing
        case contacts
        case distributionLists
        case groups
        case cspNonces
        case polls
        case messages
        case finalizing

        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    // MARK: - Public properties

    /// The phase the backup is currently in.
    public let phase: Phase

    /// Number of items written in ``phase`` so far, cumulative within the phase and restarting for each phase.
    public let itemsProcessed: UInt64

    // MARK: - Lifecycle

    init(phase: Phase, itemsProcessed: UInt64 = 0) {
        self.phase = phase
        self.itemsProcessed = itemsProcessed
    }

    init(_ stateUpdate: BackupCreateStateUpdate) {
        switch stateUpdate {
        case .initialState:
            self.init(phase: .initializing)

        case let .contacts(count):
            self.init(phase: .contacts, itemsProcessed: count)

        case let .distributionLists(count):
            self.init(phase: .distributionLists, itemsProcessed: count)

        case let .groups(count):
            self.init(phase: .groups, itemsProcessed: count)

        case let .cspNonces(count):
            self.init(phase: .cspNonces, itemsProcessed: count)

        case let .polls(count):
            self.init(phase: .polls, itemsProcessed: count)

        case let .messages(count):
            self.init(phase: .messages, itemsProcessed: count)

        case .finalizeState:
            self.init(phase: .finalizing)
        }
    }
}

#if DEBUG
    extension DataBackupProgress {
        public static func mock(phase: Phase, itemsProcessed: UInt64 = 0) -> Self {
            DataBackupProgress(phase: phase, itemsProcessed: itemsProcessed)
        }

        public static var mockRun: [DataBackupProgress] {
            [
                DataBackupProgress(phase: .initializing),
                DataBackupProgress(phase: .contacts, itemsProcessed: 412),
                DataBackupProgress(phase: .distributionLists, itemsProcessed: 7),
                DataBackupProgress(phase: .groups, itemsProcessed: 38),
                DataBackupProgress(phase: .cspNonces, itemsProcessed: 12904),
                DataBackupProgress(phase: .polls, itemsProcessed: 3),
                DataBackupProgress(phase: .messages, itemsProcessed: 84120),
                DataBackupProgress(phase: .finalizing),
            ]
        }
    }
#endif
