import Foundation

extension UInt64 {
    var date: Date? {
        Date(millisecondsSince1970: self)
    }
}
