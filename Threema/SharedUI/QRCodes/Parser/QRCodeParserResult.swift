import Foundation
import ThreemaEssentials
import ThreemaMacros

enum QRCodeParserResult {
    case identityContact(identity: ThreemaIdentity, publicKey: Data, expirationDate: Date?)
    case identityLink(url: URL)
    case multiDeviceLink(urlSafeBase64: String)
    case webSession(session: [String: Any], authToken: Data)
}
