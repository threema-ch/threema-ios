import Foundation
import RemoteSecretProtocol

struct EmptyRemoteSecretCrypto: RemoteSecretCryptoProtocol {
    let coder: any SendableRemoteSecretCodable = EmptyRemoteSecretCoder()
    
    func encrypt(_ data: inout Data) {
        // no-op
    }
    
    func decrypt(_ data: inout Data) {
        // no-op
    }
    
    func encrypt(_ data: Data) -> Data {
        fatalError("This should not be called")
    }
    
    func decrypt(_ data: Data) -> Data {
        fatalError("This should not be called")
    }
    
    func encrypt(_ string: String) -> Data {
        fatalError("This should not be called")
    }
    
    func decrypt(_ data: Data) -> String {
        fatalError("This should not be called")
    }
    
    func encrypt(_ int: Int16) -> Data {
        fatalError("This should not be called")
    }
    
    func decrypt(_ data: Data) -> Int16 {
        fatalError("This should not be called")
    }
    
    func encrypt(_ int: Int32) -> Data {
        fatalError("This should not be called")
    }
    
    func decrypt(_ data: Data) -> Int32 {
        fatalError("This should not be called")
    }
    
    func encrypt(_ int: Int64) -> Data {
        fatalError("This should not be called")
    }
    
    func decrypt(_ data: Data) -> Int64 {
        fatalError("This should not be called")
    }
    
    func encrypt(_ double: Double) -> Data {
        fatalError("This should not be called")
    }
    
    func decrypt(_ data: Data) -> Double {
        fatalError("This should not be called")
    }
    
    func encrypt(_ float: Float) -> Data {
        fatalError("This should not be called")
    }
    
    func decrypt(_ data: Data) -> Float {
        fatalError("This should not be called")
    }
    
    func encrypt(_ date: Date) -> Data {
        fatalError("This should not be called")
    }
    
    func decrypt(_ data: Data) -> Date {
        fatalError("This should not be called")
    }
    
    func encrypt(_ bool: Bool) -> Data {
        fatalError("This should not be called")
    }
    
    func decrypt(_ data: Data) -> Bool {
        fatalError("This should not be called")
    }
}
