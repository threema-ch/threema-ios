import ThreemaEssentials

extension LibthreemaThreemaID {
    public init(threemaIdentity: ThreemaIdentity) {
        self = threemaIdentity.rawValue
    }
}
