import libthreemaSwift

extension LibthreemaActivityState {
    init?(_ contactState: ContactEntity.ContactState) {
        let libthreemaActivityState: LibthreemaActivityState =
            switch contactState {
            case .active: .active
            case .inactive: .inactive
            case .invalid: .invalid
            }
        self.init(rawValue: libthreemaActivityState.rawValue)
    }
}
