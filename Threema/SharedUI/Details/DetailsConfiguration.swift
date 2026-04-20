import Foundation

/// Configuration used by multiple detail views
///
/// Normally you don't create your own implementation but use the default implementation
protocol DetailsConfiguration {
    /// Size of the big profile picture
    var profilePictureSize: CGFloat { get }
    
    /// Font for contact or group name. Based on current dynamic type setting.
    var nameFont: UIFont { get }
}

// Default implementation
extension DetailsConfiguration {
    var profilePictureSize: CGFloat { 120 }
    
    var nameFont: UIFont {
        let title2Font = UIFont.preferredFont(forTextStyle: .title2)
        return UIFont.systemFont(ofSize: title2Font.pointSize + 2, weight: .semibold)
    }
}
