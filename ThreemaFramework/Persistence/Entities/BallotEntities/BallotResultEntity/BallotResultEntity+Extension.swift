import Foundation

extension BallotResultEntity {
    public var boolValue: Bool {
        value?.boolValue ?? false
    }
}
