import Foundation

@objc
public final class ThreemaLicense: NSObject {
    public let user: String
    public let password: String
    public let deviceID: String?
    public let onPremServer: String?
    
    public init(
        user: String,
        password: String,
        deviceID: String?,
        onPremServer: String?
    ) {
        self.user = user
        self.password = password
        self.deviceID = deviceID
        self.onPremServer = onPremServer
    }
}
