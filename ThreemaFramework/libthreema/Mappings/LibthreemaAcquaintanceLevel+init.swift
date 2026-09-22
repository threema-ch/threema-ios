import libthreemaSwift

extension LibthreemaAcquaintanceLevel {
    init?(_ isHiddenContact: HiddenContact) {
        let libthreemaAcquaintanceLevel: LibthreemaAcquaintanceLevel = isHiddenContact ? .groupOrDeleted : .direct
        self.init(rawValue: libthreemaAcquaintanceLevel.rawValue)
    }
}
