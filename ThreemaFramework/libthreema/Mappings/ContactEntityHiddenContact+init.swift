import libthreemaSwift

public typealias HiddenContact = Bool

extension HiddenContact {
    init(_ libthreemaAcquaintanceLevel: LibthreemaAcquaintanceLevel) {
        self = libthreemaAcquaintanceLevel != .direct
    }
}
