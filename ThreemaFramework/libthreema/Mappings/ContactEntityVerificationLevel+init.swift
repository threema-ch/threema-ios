import libthreemaSwift

extension ContactEntity.VerificationLevel {
    init?(_ libthreemaVerificationLevel: LibthreemaVerificationLevel) {
        let verificationLevel: ContactEntity.VerificationLevel =
            switch libthreemaVerificationLevel {
            case .fullyVerified: .fullyVerified
            case .serverVerified: .serverVerified
            case .unverified: .unverified
            }
        self.init(rawValue: verificationLevel.rawValue)
    }
}
