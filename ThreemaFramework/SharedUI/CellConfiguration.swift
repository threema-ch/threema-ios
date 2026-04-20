import Foundation

/// Shared configuration between `ContactCell`, `GroupCell` & `DistributionListCell`
public struct CellConfiguration {
    
    public enum Size {
        case small
        case medium
    }
    
    private let size: Size
    
    // MARK: Configuration & helpers
        
    public var nameLabelFont: UIFont {
        switch size {
        case .small:
            return .preferredFont(forTextStyle: .headline)
        case .medium:
            let headlineFont = UIFont.preferredFont(forTextStyle: .headline)
            let labelFont = UIFont.systemFont(ofSize: headlineFont.pointSize + 1, weight: .semibold)
            return labelFont
        }
    }
    
    private let maxSmallProfilePictureSize: CGFloat = 40
    private let maxMediumProfilePictureSize: CGFloat = 48

    public var maxProfilePictureSize: CGFloat {
        if size == .medium {
            return maxMediumProfilePictureSize
        }
        
        return maxSmallProfilePictureSize
    }
    
    public let verticalSpacing: CGFloat = 4

    private let smallHorizontalSpacing: CGFloat = 10
    private let mediumHorizontalSpacing: CGFloat = 12
    
    public var horizontalSpacing: CGFloat {
        if size == .medium {
            return mediumHorizontalSpacing
        }
        
        return smallHorizontalSpacing
    }
    
    // MARK: - Lifecycle
    
    public init(size: Size) {
        self.size = size
    }
}
