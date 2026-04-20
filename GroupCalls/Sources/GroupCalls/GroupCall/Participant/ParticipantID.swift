import Foundation

struct ParticipantID: Sendable {
    var id: UInt32 {
        didSet {
            if id >= MIDS_MAX {
                fatalError("Not a valid participant id: \(id)")
            }
        }
    }
}

// MARK: - CustomStringConvertible

extension ParticipantID: CustomStringConvertible {
    var description: String {
        String(id)
    }
}

// MARK: - Equatable

extension ParticipantID: Equatable {
    static func == (lhs: ParticipantID, rhs: ParticipantID) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Hashable

extension ParticipantID: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
