import Foundation

enum QRCodeParserError: Error, LocalizedError, Equatable {
    case invalidFormat(String)

    var errorDescription: String? {
        switch self {
        case let .invalidFormat(reason):
            reason
        }
    }
}
