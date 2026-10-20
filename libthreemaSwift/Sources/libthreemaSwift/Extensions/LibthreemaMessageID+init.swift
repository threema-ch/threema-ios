import Foundation

extension LibthreemaMessageID {
    public init(rawValue: Data) throws {
        self = try rawValue.littleEndian()
    }
}
