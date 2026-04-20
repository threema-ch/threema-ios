import Foundation

extension Colors {
                
    @objc public class var threemaLogo: UIImage {
        switch TargetManager.current {
        case .threema:
            UIImage(resource: .threema)
        case .work:
            UIImage(resource: .threemaWork)
        case .onPrem:
            UIImage(resource: .threemaOnPrem)
        case .customOnPrem:
            UIImage(resource: .customOnPrem)
        case .green:
            UIImage(resource: .threemaGreen)
        case .blue:
            UIImage(resource: .threemaBlue)
        }
    }

    @objc public class var darkConsumerLogo: UIImage {
        UIImage(resource: .threemaBlackLogo)
    }
        
    @objc public class var threemaLogoForPasscode: UIImage {
        switch TargetManager.current {
        case .threema:
            UIImage(resource: .passcodeLogo)
        case .work:
            UIImage(resource: .passcodeLogoWork)
        case .onPrem:
            UIImage(resource: .passcodeLogoOnprem)
        case .customOnPrem:
            UIImage(resource: .passcodeLogoCustomOnprem)
        case .green:
            UIImage(resource: .passcodeLogoGreen)
        case .blue:
            UIImage(resource: .passcodeLogoBlue)
        }
    }
    
    @objc public class var consumerAppIcon: UIImage {
        switch TargetManager.current {
        case .blue:
            UIImage(resource: .passcodeLogoGreen)
        case .threema, .work, .onPrem, .customOnPrem, .green:
            UIImage(resource: .passcodeLogo)
        }
    }
    
    @objc public class var callKitLogo: UIImage {
        switch TargetManager.current {
        case .threema, .work, .onPrem, .green, .blue:
            UIImage(resource: .voipThreema)
        case .customOnPrem:
            UIImage(resource: .voipCustom)
        }
    }
}
