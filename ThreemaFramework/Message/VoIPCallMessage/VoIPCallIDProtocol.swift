import Foundation

public protocol VoIPCallIDProtocol {
    var callID: VoIPCallID { get }
    var contactIdentity: String! { get }
}
