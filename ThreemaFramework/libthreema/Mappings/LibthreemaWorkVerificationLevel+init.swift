import libthreemaSwift

extension LibthreemaWorkVerificationLevel {
    init?(_ isWorkContact: WorkContact) {
        let libthreemaWorkVerificationLevel: LibthreemaWorkVerificationLevel = isWorkContact ?
            .workSubscriptionVerified : .none
        self.init(rawValue: libthreemaWorkVerificationLevel.rawValue)
    }
}
