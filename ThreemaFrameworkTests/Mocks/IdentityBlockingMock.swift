import ThreemaEssentials

struct IdentityBlockingMock: IdentityBlocking {
    
    var state: IdentityBlockingState = .notBlocked
    
    func check(identity: ThreemaIdentity) -> IdentityBlockingState {
        state
    }
}
