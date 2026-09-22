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
}

// MARK: Shadows

extension Colors {
    public class var shadowNotification: UIColor {
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
    public class var licenseLogoURL: String? {
        switch Colors.theme {
        case .light:
            MyIdentityStore.shared().licenseLogoLightURL
        case .dark:
            MyIdentityStore.shared().licenseLogoDarkURL
        }
    }
}
