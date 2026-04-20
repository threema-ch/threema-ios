public struct ThreemaSafeServerInfo {
    public let user: String?
    public let password: String?
    public let server: String
    
    public init(
        user: String?,
        password: String?,
        server: String
    ) {
        self.user = user
        self.password = password
        self.server = server
    }
}
