import Foundation

extension StyleKit {
    public static func verificationImage(for level: Int) -> UIImage {
        switch level {
        case 0:
            StyleKit.verification0
        case 1:
            StyleKit.verification1
        case 2:
            StyleKit.verification2
        case 3:
            StyleKit.verification3
        case 4:
            StyleKit.verification4
        default:
            fatalError("Unknown verification level \(level)")
        }
    }
    
    public static func verificationImageBig(for level: Int) -> UIImage {
        switch level {
        case 0:
            StyleKit.verificationBig0
        case 1:
            StyleKit.verificationBig1
        case 2:
            StyleKit.verificationBig2
        case 3:
            StyleKit.verificationBig3
        case 4:
            StyleKit.verificationBig4
        default:
            fatalError("Unknown verification level \(level)")
        }
    }
}
