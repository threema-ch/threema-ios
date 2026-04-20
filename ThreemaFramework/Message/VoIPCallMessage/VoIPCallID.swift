import CocoaLumberjackSwift
import Foundation

@objc public final class VoIPCallID: NSObject {
    public let callID: UInt32
    
    public init(callID: UInt32) {
        self.callID = callID
    }
    
    public static func generate() -> VoIPCallID {
        VoIPCallID(callID: UInt32.random(in: 0...UInt32.max))
    }
    
    override public func isEqual(_ object: Any?) -> Bool {
        callID == (object as? VoIPCallID)?.callID
    }
}
