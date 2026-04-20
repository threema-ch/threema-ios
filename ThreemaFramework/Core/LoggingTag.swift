import Foundation

enum LoggingTag: UInt8 {
    case none = 0x00

    case receiveIncomingMessageFromChat = 0x15
    case sendIncomingMessageAckToChat = 0x33
    case receiveIncomingMessageFromMediator = 0x78
    case sendIncomingMessageAckToMediator = 0x65
    case reflectIncomingMessageToMediator = 0x91
    case receiveIncomingMessageAckFromMediator = 0x24
    case reflectIncomingMessageUpdateToMediator = 0x31
    case receiveIncomingMessageUpdateAckFromMediator = 0x56

    case sendOutgoingMessageToChat = 0x82
    case receiveOutgoingMessageAckFromChat = 0x93
    case reflectOutgoingMessageToMediator = 0x03
    case receiveOutgoingMessageAckFromMediator = 0x55
    case reflectOutgoingMessageUpdateToMediator = 0x21
    case receiveOutgoingMessageUpdateAckFromMediator = 0x52

    case sendBeginTransactionToMediator = 0x34
    case receiveBeginTransactionAckFromMediator = 0x13
    case receiveTransactionRejectedFromMediator = 0x29
    case sendCommitTransactionToMediator = 0x61
    case receiveTransactionEndedFromMediator = 0x72

    var hexString: String {
        "[0x\(String(format: "%02hhx", rawValue))]"
    }
}
