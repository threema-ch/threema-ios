import ThreemaEssentials

public struct MyIdentity {
    @RawValueAccessible
    public var identity: ThreemaIdentity
    
    @RawValueAccessible
    public var clientKey: ThreemaClientKey
    
    @RawValueAccessible
    public var publicKey: ThreemaPublicKey
    
    @RawValueAccessible
    public var serverGroup: ServerGroup
    
    public init(
        identity: ThreemaIdentity,
        clientKey: ThreemaClientKey,
        publicKey: ThreemaPublicKey,
        serverGroup: ServerGroup
    ) {
        self.identity = identity
        self.clientKey = clientKey
        self.publicKey = publicKey
        self.serverGroup = serverGroup
    }
}
