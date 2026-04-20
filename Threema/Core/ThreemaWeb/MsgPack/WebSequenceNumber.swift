import Foundation

final class WebSequenceNumber: NSObject {
    private var minValue: UInt64
    private var maxValue: UInt64
    private var _value: UInt64
    var value: UInt64 {
        set {
            if isValid(other: UInt64(newValue)) == true {
                _value = newValue
            }
        }
        get { _value }
    }
    
    init(initialValue: UInt64 = 0, minValue: UInt64, maxValue: UInt64) {
        self.minValue = minValue
        self.maxValue = maxValue
        self._value = initialValue
    }
    
    func isValid(other: UInt64) -> Bool {
        if other < minValue {
            return false
        }
        if other > maxValue {
            return false
        }
        return true
    }
    
    func increment(by: UInt64 = 1) -> UInt64? {
        let tmpValue = _value
        value = tmpValue + by
        return value
    }
}
