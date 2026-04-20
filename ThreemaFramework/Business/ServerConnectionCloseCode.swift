import Foundation

@objc enum ServerConnectionCloseCode: Int {
    case unsupportedProtocolVersion = 4110
    case duplicateConnection = 4112
    case deviceSlotStateMismatch = 4115
}
