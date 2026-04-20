import Foundation
import ThreemaEssentials
@testable import RemoteSecret

final class RemoteSecretCoderMock: RemoteSecretCodable, @unchecked Sendable {
    enum RemoteSecretCoderCall: Equatable, @unchecked Sendable {
        case encodeString(String)
        case decodeString(Data)
        case encodeFixedWidthInteger(any FixedWidthInteger)
        case decodeFixedWidthInteger(Data)
        case encodeDouble(Double)
        case decodeDouble(Data)
        case encodeFloat(Float)
        case decodeFloat(Data)
        case encodeDate(Date)
        case decodeDate(Data)
        case encodeBool(Bool)
        case decodeBool(Data)

        static func == (
            lhs: RemoteSecretCoderCall,
            rhs: RemoteSecretCoderCall
        ) -> Bool {
            switch (lhs, rhs) {
            case let (.encodeString(lhsValue), .encodeString(rhsValue)):
                lhsValue == rhsValue
            case let (.decodeString(lhsValue), .decodeString(rhsValue)):
                lhsValue == rhsValue
            case let (.encodeFixedWidthInteger(lhsValue), .encodeFixedWidthInteger(rhsValue)):
                String(describing: lhsValue) == String(describing: rhsValue)
            case let (.decodeFixedWidthInteger(lhsValue), .decodeFixedWidthInteger(rhsValue)):
                lhsValue == rhsValue
            case let (.encodeDouble(lhsValue), .encodeDouble(rhsValue)):
                lhsValue == rhsValue
            case let (.decodeDouble(lhsValue), .decodeDouble(rhsValue)):
                lhsValue == rhsValue
            case let (.encodeFloat(lhsValue), .encodeFloat(rhsValue)):
                lhsValue == rhsValue
            case let (.decodeFloat(lhsValue), .decodeFloat(rhsValue)):
                lhsValue == rhsValue
            case let (.encodeDate(lhsValue), .encodeDate(rhsValue)):
                lhsValue == rhsValue
            case let (.decodeDate(lhsValue), .decodeDate(rhsValue)):
                lhsValue == rhsValue
            case let (.encodeBool(lhsValue), .encodeBool(rhsValue)):
                lhsValue == rhsValue
            case let (.decodeBool(lhsValue), .decodeBool(rhsValue)):
                lhsValue == rhsValue
            default:
                false
            }
        }
    }

    // MARK: - State
    
    @Atomic
    public private(set) var calls = [RemoteSecretCoderCall]()

    // MARK: - RemoteSecretCodable

    public func encode(_ string: String) -> Data {
        $calls.append(.encodeString(string))
        return Data()
    }

    public func decode(_ data: Data) -> String {
        $calls.append(.decodeString(data))
        return ""
    }

    public func encode(_ fixedWithInteger: any FixedWidthInteger) -> Data {
        $calls.append(.encodeFixedWidthInteger(fixedWithInteger))
        return Data()
    }

    public func decode<T: FixedWidthInteger>(_ data: Data) -> T {
        $calls.append(.decodeFixedWidthInteger(data))
        return T()
    }

    public func encode(_ double: Double) -> Data {
        $calls.append(.encodeDouble(double))
        return Data()
    }

    public func decode(_ data: Data) -> Double {
        $calls.append(.decodeDouble(data))
        return Double()
    }

    public func encode(_ float: Float) -> Data {
        $calls.append(.encodeFloat(float))
        return Data()
    }

    public func decode(_ data: Data) -> Float {
        $calls.append(.decodeFloat(data))
        return Float()
    }

    public func encode(_ date: Date) -> Data {
        $calls.append(.encodeDate(date))
        return Data()
    }

    public func decode(_ data: Data) -> Date {
        $calls.append(.decodeDate(data))
        return Date()
    }

    public func encode(_ bool: Bool) -> Data {
        $calls.append(.encodeBool(bool))
        return Data()
    }

    public func decode(_ data: Data) -> Bool {
        $calls.append(.decodeBool(data))
        return Bool()
    }

    // MARK: - Test helpers

    public func resetCalls() {
        $calls.removeAll()
    }

    public func callCount(of expected: RemoteSecretCoderCall) -> Int {
        calls.reduce(0) { $0 + ($1 == expected ? 1 : 0) }
    }
}
