@propertyWrapper
public struct RawValueAccessible<T: RawRepresentable> {
    public var wrappedValue: T
    
    public var projectedValue: T.RawValue {
        wrappedValue.rawValue
    }
    
    public init(wrappedValue: T) {
        self.wrappedValue = wrappedValue
    }
}
