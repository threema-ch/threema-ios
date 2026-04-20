import Foundation

@objc final class ForwardSecurityContact: NSObject {
    let identity: String
    let publicKey: Data
    
    @objc init(identity: String, publicKey: Data) {
        self.identity = identity
        self.publicKey = publicKey
    }
}
