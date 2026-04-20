import CocoaLumberjackSwift
import Foundation

public struct ThreemaIdentity: StringRepresentable, Equatable, Hashable, CustomStringConvertible, Sendable {
    
    /// Expected length of string representing a `ThreemaIdentity`
    public static let length = 8
    
    public let rawValue: String

    public init(rawValue: String) {
        if rawValue.count != ThreemaIdentity.length {
            assertionFailure("Tried to create a ThreemaIdentity with length of \(rawValue.count)")
            DDLogError("Tried to create a ThreemaIdentity with length of \(rawValue.count)")
        }

        self.rawValue = rawValue.uppercased()
    }

    public var description: String {
        rawValue
    }
    
    public var isGatewayID: Bool {
        rawValue.hasPrefix("*")
    }
}

// MARK: - Codable

// We need a custom Codable implementation because `RawRepresentable` (which we conform to through
// `StringRepresentable`) brings it's own implementation that doesn't conform to the previous format. This restores this
// previous format for backwards compatibility.
extension ThreemaIdentity: Codable {
    private enum CodingKeys: String, CodingKey {
        case rawValue = "string"
    }
    
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.rawValue = try values.decode(String.self, forKey: .rawValue)
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rawValue, forKey: .rawValue)
    }
}
