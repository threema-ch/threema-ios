import Foundation

public enum ImageSenderItemSize: String, CaseIterable {
    case small
    case medium
    case large
    case extraLarge = "xlarge"
    case original
    
    public var resolution: CGFloat {
        switch self {
        case .small:
            640
        case .medium:
            1024
        case .large:
            1600
        case .extraLarge:
            2592
        case .original:
            0
        }
    }
}
