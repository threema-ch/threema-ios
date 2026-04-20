import Foundation
import RemoteSecretProtocol

struct EmptyRemoteSecretCoder: RemoteSecretCodable {
    func decode(_ data: Data) -> String {
        fatalError("This should not be called")
    }
    
    func decode<T>(_ data: Data) -> T where T: FixedWidthInteger {
        fatalError("This should not be called")
    }
    
    func decode(_ data: Data) -> Double {
        fatalError("This should not be called")
    }
    
    func decode(_ data: Data) -> Float {
        fatalError("This should not be called")
    }
    
    func decode(_ data: Data) -> Date {
        fatalError("This should not be called")
    }
    
    func decode(_ data: Data) -> Bool {
        fatalError("This should not be called")
    }
    
    func encode(_ string: String) -> Data {
        fatalError("This should not be called")
    }
    
    func encode(_ fixedWithInteger: any FixedWidthInteger) -> Data {
        fatalError("This should not be called")
    }
    
    func encode(_ double: Double) -> Data {
        fatalError("This should not be called")
    }
    
    func encode(_ float: Float) -> Data {
        fatalError("This should not be called")
    }
    
    func encode(_ date: Date) -> Data {
        fatalError("This should not be called")
    }
    
    func encode(_ bool: Bool) -> Data {
        fatalError("This should not be called")
    }
}
