import Foundation
import ThreemaEssentials

public struct ThreemaPublicKey: DataRepresentable {
    public var rawValue: Data
    
    public init(rawValue: Data) {
        self.rawValue = rawValue
    }
}
