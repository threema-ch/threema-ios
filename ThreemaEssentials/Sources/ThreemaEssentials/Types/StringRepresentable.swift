import Foundation

public protocol StringRepresentable: RawRepresentable {
    var rawValue: String { get }
    
    init(rawValue: String)
}

extension StringRepresentable {
    public init(_ rawValue: String) {
        self.init(rawValue: rawValue)
    }
}
