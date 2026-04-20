import Foundation

extension Date {
    public var millisecondsSince1970: UInt64 {
        UInt64((timeIntervalSince1970 * 1000.0).rounded())
    }

    public init(millisecondsSince1970: UInt64) {
        self = Date(timeIntervalSince1970: TimeInterval(millisecondsSince1970) / 1000)
    }
}

extension Date {
    private enum Holder {
        static var _currentDate: Date?
    }
    
    /// Should **only** be used for Testing
    public static var currentDate: Date {
        get {
            Holder._currentDate ?? Date.now
        }
        set {
            #if DEBUG
                Holder._currentDate = newValue
            #endif
            
            // no-op
        }
    }
}
