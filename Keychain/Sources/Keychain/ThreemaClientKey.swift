import Foundation
import ThreemaEssentials

public struct ThreemaClientKey: DataRepresentable {
    public var rawValue: Data
    
    public init(rawValue: Data) {
        self.rawValue = rawValue
    }
}
