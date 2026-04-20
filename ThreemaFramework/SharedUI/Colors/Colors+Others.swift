import Foundation

extension Colors {
    @objc public class var hairLine: UIColor {
        switch theme {
        case .light:
            UIColor(resource: .gray400)
        case .dark:
            UIColor(resource: .gray800)
        }
    }
    
    @objc public class var hairLineBallot: UIColor {
        Colors.backgroundNavigationController
    }
        
    @objc public class var qrCodeTint: UIColor {
        switch theme {
        case .light:
            .black
        case .dark:
            .white
        }
    }
}

// MARK: Shadows

extension Colors {
    @objc public class var shadowNotification: UIColor {
        switch theme {
        case .light:
            .black
        case .dark:
            .white
        }
    }
}

// MARK: URLs

extension Colors {
    @objc public class var licenseLogoURL: String? {
        switch Colors.theme {
        case .light:
            MyIdentityStore.shared().licenseLogoLightURL
        case .dark:
            MyIdentityStore.shared().licenseLogoDarkURL
        }
    }
}
