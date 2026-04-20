import Foundation

extension BaseMessageEntity {
    public var hasMarkers: Bool {
        guard let messageMarkers else {
            return false
        }
        
        return messageMarkers.star.boolValue
    }
}
