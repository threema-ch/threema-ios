import Foundation
import GroupCalls

final class GroupCallDateFormatterAdapter: GroupCallDateFormatterProtocol {
    func timeFormatted(_ totalSeconds: TimeInterval) -> String {
        DateFormatter.timeFormatted(Int(totalSeconds))
    }
    
    func accessibilityString(at time: TimeInterval, with prefix: String) -> String {
        ThreemaUtilityObjC.accessibilityString(atTime: time, withPrefix: prefix)
    }
}
