import libthreemaSwift

extension ContactEntity.ContactState {
    init?(_ libthreemaActivityState: LibthreemaActivityState) {
        let contactState: ContactEntity.ContactState =
            switch libthreemaActivityState {
            case .active: .active
            case .inactive: .inactive
            case .invalid: .invalid
            }
        self.init(rawValue: contactState.rawValue)
    }
}
