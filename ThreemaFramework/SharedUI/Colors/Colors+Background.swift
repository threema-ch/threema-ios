import Foundation

extension Colors {
    @objc public class var backgroundViewController: UIColor {
        .systemBackground
    }
    
    @objc public class var backgroundGroupedViewController: UIColor {
        .systemGroupedBackground
    }
    
    @objc public class var backgroundNavigationController: UIColor {
        .systemBackground
    }
        
    @objc public class var backgroundToolbar: UIColor {
        switch theme {
        case .light:
            .white
        case .dark:
            .black
        }
    }
    
    @objc public class var backgroundView: UIColor {
        .systemGroupedBackground
    }
    
    @objc public class var backgroundInverted: UIColor {
        .systemFill
    }
    
    @objc public class var backgroundButton: UIColor {
        switch theme {
        case .light:
            UIColor(resource: .gray450)
        case .dark:
            UIColor(resource: .gray700)
        }
    }
    
    @objc public class var backgroundChatBarButton: UIColor {
        .systemGray
    }
    
    @objc public class var backgroundChevronCircleButton: UIColor {
        switch theme {
        case .light:
            UIColor(resource: .gray250)
        case .dark:
            UIColor(resource: .gray800)
        }
    }
    
    @objc public class var backgroundTintChevronCircleButton: UIColor {
        switch theme {
        case .light:
            UIColor(resource: .gray550)
        case .dark:
            UIColor(resource: .gray400)
        }
    }
    
    @objc public class var backgroundSafeImageCircle: UIColor {
        UIColor(resource: .gray250)
    }
    
    @objc public class var backgroundWizard: UIColor {
        .black
    }
    
    @objc public class var backgroundNotification: UIColor {
        switch theme {
        case .light:
            .white
        case .dark:
            .black
        }
    }
    
    public class var backgroundWizardBox: UIColor {
        switch theme {
        case .light:
            UIColor(resource: .gray500)
        case .dark:
            UIColor(resource: .gray700)
        }
    }
}
