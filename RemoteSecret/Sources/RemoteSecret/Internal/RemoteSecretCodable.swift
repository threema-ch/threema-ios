import Foundation

protocol RemoteSecretEncodable {
    // MARK: String
    
    func encode(_ string: String) -> Data
    
    // MARK: FixedWithInteger
    
    func encode(_ fixedWithInteger: any FixedWidthInteger) -> Data
    
    // MARK: Double
    
    func encode(_ double: Double) -> Data
    
    // MARK: Float
    
    func encode(_ float: Float) -> Data
    
    // MARK: Date
    
    func encode(_ date: Date) -> Data
    
    // MARK: Bool
    
    func encode(_ bool: Bool) -> Data
}

protocol RemoteSecretDecodable {
    // MARK: String
    
    func decode(_ data: Data) -> String
    
    // MARK: FixedWithInteger
    
    func decode<T: FixedWidthInteger>(_ data: Data) -> T
    
    // MARK: Double
    
    func decode(_ data: Data) -> Double
    
    // MARK: Float
    
    func decode(_ data: Data) -> Float
    
    // MARK: Date
    
    func decode(_ data: Data) -> Date
    
    // MARK: Bool
    
    func decode(_ data: Data) -> Bool
}

typealias RemoteSecretCodable = RemoteSecretEncodable & RemoteSecretDecodable

typealias SendableRemoteSecretCodable = RemoteSecretCodable & Sendable
