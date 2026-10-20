import libthreemaSwift

extension DeletedMessageState {
    init(baseMessageEntity: some BaseMessageEntity) throws {
        guard let deletedAt = baseMessageEntity.deletedAt else {
            throw MappingError.messageDeletedAtMissing
        }

        let previousMessageType: MessageStateBodyType
        switch baseMessageEntity {
        case is BallotMessageEntity:
            guard let state = (baseMessageEntity as? BallotMessageEntity)?.ballotState?.intValue else {
                previousMessageType = .deleted
                break
            }

            if state == BallotEntity.BallotState.closed.rawValue {
                previousMessageType = .pollClose
            }
            else if state == BallotEntity.BallotState.open.rawValue {
                previousMessageType = .pollOpen
            }
            else {
                assertionFailure("Unknown ballot state")
                previousMessageType = .deleted
            }
        case is LocationMessageEntity:
            previousMessageType = .location
        case is TextMessageEntity:
            previousMessageType = .text
        default:
            assertionFailure("Is there a type for the deleted message yet?")
            previousMessageType = .deleted
        }

        self.init(
            previousMessageType: previousMessageType,
            deletedAt: deletedAt.millisecondsSince1970.littleEndian
        )
    }
}
