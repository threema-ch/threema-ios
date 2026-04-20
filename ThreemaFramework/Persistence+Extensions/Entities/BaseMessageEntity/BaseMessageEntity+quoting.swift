import Foundation

extension BaseMessageEntity {
    /// Is quoting of this message allowed?
    public var supportsQuoting: Bool {
        !isDistributionListMessage
    }
}
