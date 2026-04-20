import Foundation

struct RemoteSecretCoder: SendableRemoteSecretCodable {
    private let logErrorMessage: @Sendable (String) -> Void
    
    init(logErrorMessage: @escaping @Sendable (String) -> Void = { _ in }) {
        self.logErrorMessage = logErrorMessage
    }
    
    // MARK: String
    
    func encode(_ string: String) -> Data {
        Data(string.utf8)
    }
    
    func decode(_ data: Data) -> String {
        let decoded = String(data: data, encoding: .utf8)
        
        guard let decoded else {
            let message = "[RemoteSecret] Could not decode string."
            logErrorMessage(message)
            fatalError(message)
        }
        
        return decoded
    }
    
    // MARK: FixedWithInteger
    
    func encode(_ fixedWithInteger: any FixedWidthInteger) -> Data {
        fixedWithInteger.littleEndianData
    }
    
    func decode<T: FixedWidthInteger>(_ data: Data) -> T {
        do {
            return try data.littleEndian()
        }
        catch {
            let message = "[RemoteSecret] Could not decode fixed width integer."
            logErrorMessage(message)
            fatalError(message)
        }
    }
    
    // MARK: Double
    
    func encode(_ double: Double) -> Data {
        encode(double.bitPattern)
    }
    
    func decode(_ data: Data) -> Double {
        let bitPattern: UInt64 = decode(data)
        return Double(bitPattern: bitPattern)
    }
    
    // MARK: Float
    
    func encode(_ float: Float) -> Data {
        encode(float.bitPattern)
    }
    
    func decode(_ data: Data) -> Float {
        let bitPattern: UInt32 = decode(data)
        return Float(bitPattern: bitPattern)
    }
    
    // MARK: Date
    
    func encode(_ date: Date) -> Data {
        encode(date.timeIntervalSince1970)
    }
    
    func decode(_ data: Data) -> Date {
        Date(timeIntervalSince1970: decode(data))
    }
    
    // MARK: Bool
    
    func encode(_ bool: Bool) -> Data {
        encode(bool ? 1 : 0)
    }
    
    func decode(_ data: Data) -> Bool {
        let int: Int = decode(data)
        guard int == 1 || int == 0 else {
            let message = "[RemoteSecret] Could not decode bool for int value: \(int)"
            logErrorMessage(message)
            fatalError(message)
        }
        return int == 1
    }
}
