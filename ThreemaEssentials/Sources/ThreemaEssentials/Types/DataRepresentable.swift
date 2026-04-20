import Foundation

public protocol DataRepresentable: RawRepresentable {
    var rawValue: Data { get }
    
    init(rawValue: Data)
}

extension DataRepresentable {
    public init(_ rawValue: Data) {
        self.init(rawValue: rawValue)
    }
}
