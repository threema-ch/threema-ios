import libthreemaSwift

public struct DataRestoreProgress: Equatable, Hashable, Sendable {

    // MARK: - Public types

    public enum Phase: Int, CaseIterable, Comparable, Sendable {
        case preparing
        case contacts
        case distributionLists
        case groups
        case cspNonces
        case polls
        case messages

        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    // MARK: - Public properties

    public let phase: Phase

    // MARK: - Lifecycle

    init(phase: Phase) {
        self.phase = phase
    }

    public init(_ stateUpdate: BackupRestoreStateUpdate) {
        switch stateUpdate {
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
        }
    }
}

#if DEBUG
    extension DataRestoreProgress {
        public static func mock(phase: Phase) -> Self {
            DataRestoreProgress(phase: phase)
        }

        public static var mockRun: [DataRestoreProgress] {
            Phase.allCases.map { DataRestoreProgress(phase: $0) }
        }
    }
#endif
