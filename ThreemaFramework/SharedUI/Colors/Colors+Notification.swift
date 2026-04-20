import Foundation

extension Colors {
    public class var pillBackground: UIColor {
        switch theme {
        case .light:
            .white
        case .dark:
            UIColor(resource: .gray900)
        }
    }
    
    public class var pillText: UIColor {
        switch theme {
        case .light:
            .secondaryLabel.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        case .dark:
            .secondaryLabel.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        }
    }
    
    public class var pillShadow: UIColor {
        switch theme {
        case .light:
            .black.withAlphaComponent(0.3)
        case .dark:
            .clear
        }
    }
}
