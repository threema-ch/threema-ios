import libthreemaSwift

extension MessageStarMarker {
    init(baseMessageEntity: BaseMessageEntity) {
        guard let messagesMarkers = baseMessageEntity.messageMarkers else {
            self = .none
            return
        }

        self = messagesMarkers.star.boolValue ? .star : .none
    }
}
