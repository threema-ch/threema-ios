import Foundation
import RemoteSecretProtocol
import ThreemaEssentials

public enum RemoteSecretCryptoCall: Equatable, Sendable {
    case encryptDataInout(Data)
    case decryptDataInout(Data)
    case encryptData(Data)
    case decryptData(Data)
    case encryptString(String)
    case decryptDataToString(Data)
    case encryptInt16(Int16)
    case decryptDataToInt16(Data)
    case encryptInt32(Int32)
    case decryptDataToInt32(Data)
    case encryptInt64(Int64)
    case decryptDataToInt64(Data)
    case encryptDouble(Double)
    case decryptDataToDouble(Data)
    case encryptFloat(Float)
    case decryptDataToFloat(Data)
    case encryptDate(Date)
    case decryptDataToDate(Data)
    case encryptBool(Bool)
    case decryptDataToBool(Data)
}

public final class RemoteSecretCryptoMock: RemoteSecretCryptoProtocol, @unchecked Sendable {
    @Atomic
    public private(set) var calls: [RemoteSecretCryptoCall] = []
    
    @Atomic
    public var encryptCalls = 0
    
    @Atomic
    public var decryptCalls = 0
    
    let wrapped: RemoteSecretCryptoProtocol?
    
    // MARK: - Lifecycle
    
    public init(wrapped: RemoteSecretCryptoProtocol? = nil) {
        self.wrapped = wrapped
    }
    
    // MARK: - Functions
    
    public func encrypt(_ data: Data) -> Data {
        $calls.append(.encryptData(data))
        $encryptCalls += 1
        return wrapped?.encrypt(data) ?? Data()
    }
    
    public func decrypt(_ data: Data) -> Data {
        $calls.append(.decryptData(data))
        $decryptCalls += 1
        return wrapped?.decrypt(data) ?? Data()
    }
    
    public func encrypt(_ string: String) -> Data {
        $calls.append(.encryptString(string))
        $encryptCalls += 1
        return wrapped?.encrypt(string) ?? Data()
    }
    
    public func decrypt(_ data: Data) -> String {
        $calls.append(.decryptDataToString(data))
        $decryptCalls += 1
        return wrapped?.decrypt(data) ?? String()
    }
    
    public func encrypt(_ int: Int16) -> Data {
        $calls.append(.encryptInt16(int))
        $encryptCalls += 1
        return wrapped?.encrypt(int) ?? Data()
    }
    
    public func decrypt(_ data: Data) -> Int16 {
        $calls.append(.decryptDataToInt16(data))
        $decryptCalls += 1
        return wrapped?.decrypt(data) ?? Int16()
    }
    
    public func encrypt(_ int: Int32) -> Data {
        $calls.append(.encryptInt32(int))
        $encryptCalls += 1
        return wrapped?.encrypt(int) ?? Data()
    }
    
    public func decrypt(_ data: Data) -> Int32 {
        $calls.append(.decryptDataToInt32(data))
        $decryptCalls += 1
        return wrapped?.decrypt(data) ?? Int32()
    }
    
    public func encrypt(_ int: Int64) -> Data {
        $calls.append(.encryptInt64(int))
        $encryptCalls += 1
        return wrapped?.encrypt(int) ?? Data()
    }
    
    public func decrypt(_ data: Data) -> Int64 {
        $calls.append(.decryptDataToInt64(data))
        $decryptCalls += 1
        return wrapped?.decrypt(data) ?? Int64()
    }
    
    public func encrypt(_ double: Double) -> Data {
        $calls.append(.encryptDouble(double))
        $encryptCalls += 1
        return wrapped?.encrypt(double) ?? Data()
    }
    
    public func decrypt(_ data: Data) -> Double {
        $calls.append(.decryptDataToDouble(data))
        $decryptCalls += 1
        return wrapped?.decrypt(data) ?? Double()
    }
    
    public func encrypt(_ float: Float) -> Data {
        $calls.append(.encryptFloat(float))
        $encryptCalls += 1
        return wrapped?.encrypt(float) ?? Data()
    }
    
    public func decrypt(_ data: Data) -> Float {
        $calls.append(.decryptDataToFloat(data))
        $decryptCalls += 1
        return wrapped?.decrypt(data) ?? Float()
    }
    
    public func encrypt(_ date: Date) -> Data {
        $calls.append(.encryptDate(date))
        $encryptCalls += 1
        return wrapped?.encrypt(date) ?? Data()
    }
    
    public func decrypt(_ data: Data) -> Date {
        $calls.append(.decryptDataToDate(data))
        $decryptCalls += 1
        return wrapped?.decrypt(data) ?? Date()
    }
    
    public func encrypt(_ bool: Bool) -> Data {
        $calls.append(.encryptBool(bool))
        $encryptCalls += 1
        return wrapped?.encrypt(bool) ?? Data()
    }
    
    public func decrypt(_ data: Data) -> Bool {
        $calls.append(.decryptDataToBool(data))
        $decryptCalls += 1
        return wrapped?.decrypt(data) ?? Bool()
    }
    
    // MARK: - Helpers
    
    public func resetCalls() {
        $calls.removeAll()
        encryptCalls = 0
        decryptCalls = 0
    }
}
