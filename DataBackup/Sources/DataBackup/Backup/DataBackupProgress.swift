import libthreemaSwift

/// A snapshot of an in-flight backup creation.
public struct DataBackupProgress: Equatable, Hashable, Sendable {

    // MARK: - Public types

    /// The phases a backup creation moves through, in the order they are reported in.
    public enum Phase: Int, CaseIterable, Comparable, Sendable {
        case userData
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

    // MARK: - Lifecycle

    init(phase: Phase) {
        self.phase = phase
    }

    init(_ stateUpdate: DataBackupCreateStateUpdate) {
        switch stateUpdate {
        case .userData:
            self.init(phase: .userData)

        case .contacts:
            self.init(phase: .contacts)

        case .distributionLists:
            self.init(phase: .distributionLists)

        case .groups:
            self.init(phase: .groups)

        case .cspNonces:
            self.init(phase: .cspNonces)

        case .polls:
            self.init(phase: .polls)

        case .messages:
            self.init(phase: .messages)

        case .finalize:
            self.init(phase: .finalizing)
        }
    }
}

#if DEBUG
    extension DataBackupProgress {
        public static func mock(phase: Phase) -> Self {
            DataBackupProgress(phase: phase)
        }

        public static var mockRun: [DataBackupProgress] {
            [
                DataBackupProgress(phase: .userData),
                DataBackupProgress(phase: .contacts),
                DataBackupProgress(phase: .distributionLists),
                DataBackupProgress(phase: .groups),
                DataBackupProgress(phase: .cspNonces),
                DataBackupProgress(phase: .polls),
                DataBackupProgress(phase: .messages),
                DataBackupProgress(phase: .finalizing),
            ]
        }
    }
#endif
