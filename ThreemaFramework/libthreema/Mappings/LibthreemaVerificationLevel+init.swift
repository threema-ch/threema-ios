import libthreemaSwift

extension LibthreemaVerificationLevel {
    init?(_ verificationLevel: ContactEntity.VerificationLevel) {
        let libthreemaVerificationLevel: LibthreemaVerificationLevel =
            switch verificationLevel {
            case .fullyVerified: .fullyVerified
            case .serverVerified: .serverVerified
            case .unverified: .unverified
            }

        self.init(rawValue: libthreemaVerificationLevel.rawValue)
    }
}
