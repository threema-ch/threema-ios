import CocoaLumberjackSwift
import Foundation

extension BaseMessageEntity {
    
    /// String (of `sectionDate`) used for sectioning messages
    @objc var sectionDateString: String {
        // TODO: (IOS-2393) Use relative dates
        DateFormatter.relativeMediumDate(for: sectionDate)
    }
    
    /// Date that sectioning is based on. (See `sectionDateString`)
    public var sectionDate: Date {
        guard !willBeDeleted, !wasDeleted else {
            return .now
        }
        
        if let date {
            return date
        }
        else if let remoteSentDate {
            return remoteSentDate
        }
        
        DDLogError("[BaseMessageEntity] Unable to load correct sectioning date")
        return .now
    }
    
    /// Key paths of properties used for sectioning. Use them to prefetch this information.
    static var sectioningKeyPaths: [Any] { [
        #keyPath(BaseMessageEntity.date),
        #keyPath(BaseMessageEntity.remoteSentDate),
    ] }
}
