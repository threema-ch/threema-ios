import Foundation

extension ReceiptType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .received:
            "received"
        case .read:
            "read"
        case .ack:
            "ack"
        case .decline:
            "decline"
        case .consumed:
            "consumed"
        }
    }
}
