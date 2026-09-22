import libthreemaSwift

public typealias WorkContact = Bool

extension WorkContact {
    init(_ libthreemaWorkVerificationLevel: LibthreemaWorkVerificationLevel) {
        self =
            switch libthreemaWorkVerificationLevel {
            case .workSubscriptionVerified: true
            case .none: false
            }
    }
}
