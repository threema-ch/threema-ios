import Foundation

public protocol GroupCallDateFormatterProtocol {
    func timeFormatted(_ totalSeconds: TimeInterval) -> String
    func accessibilityString(at time: TimeInterval, with prefix: String) -> String
}
