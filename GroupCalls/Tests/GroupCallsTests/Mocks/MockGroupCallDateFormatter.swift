import Foundation
@testable import GroupCalls

final class MockGroupCallDateFormatter: GroupCallDateFormatterProtocol {
    func timeFormatted(_ totalSeconds: TimeInterval) -> String {
        "\(totalSeconds)"
    }
    
    func accessibilityString(at time: TimeInterval, with prefix: String) -> String {
        "\(time)"
    }
}
