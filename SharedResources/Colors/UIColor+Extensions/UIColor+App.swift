import Foundation

extension UIColor {
    
    /// The color below serves as an example for future implementations
    private static let dynamicTestColor = UIColor { (traitCollection: UITraitCollection) -> UIColor in
        let highContrast = UIAccessibility.isDarkerSystemColorsEnabled
        
        if traitCollection.userInterfaceStyle == .dark {
            return highContrast ? .systemRed : .systemBlue
        }
        else {
            return highContrast ? .systemGreen : .systemYellow
        }
    }
    
    @objc public static var primary = UIColor { _ in
        switch TargetManager.current {
        case .threema, .green:
            UIColor(resource: .accentColorPrivate)
        case .work, .blue:
            UIColor(resource: .accentColorWork)
        case .onPrem:
            UIColor(resource: .accentColorOnPrem)
        case .customOnPrem:
            UIColor(resource: .accentColorCustomOnPrem)
        }
    }
    
    @objc public static var secondary = UIColor { _ in
        switch TargetManager.current {
        case .threema, .green:
            UIColor(resource: .secondaryPrivate)
        case .work, .blue:
            UIColor(resource: .secondaryWork)
        case .onPrem:
            UIColor(resource: .secondaryOnPrem)
        case .customOnPrem:
            UIColor(resource: .secondaryCustomOnPrem)
        }
    }
    
    @objc public static let backgroundCircleButton = UIColor { _ in
        switch TargetManager.current {
        case .threema, .green:
            .circleButtonPrivate
        case .work, .blue:
            .circleButtonWork
        case .onPrem:
            .circleButtonOnPrem
        case .customOnPrem:
            .circleButtonCustomOnPrem
        }
    }
    
    public static let linkColor = UIColor { _ in
        switch TargetManager.current {
        case .threema, .green:
            UIColor(resource: .linkColorPrivate)
        case .work, .blue:
            UIColor(resource: .accentColorWork)
        case .onPrem:
            UIColor(resource: .accentColorOnPrem)
        case .customOnPrem:
            UIColor(resource: .accentColorCustomOnPrem)
        }
    }
    
    @objc public static var primaryColorWork = UIColor { _ in
        UIColor(resource: .accentColorWork)
    }
}
