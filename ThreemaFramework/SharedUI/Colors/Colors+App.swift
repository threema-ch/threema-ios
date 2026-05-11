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
    
    public class var callKitLogo: UIImage {
        UIImage(resource: callKitLogoResource)
    }

    public class var callKitLogoResource: ImageResource {
        switch TargetManager.current {
        case .threema, .work, .onPrem, .green, .blue:
            .voipThreema
        case .customOnPrem:
            .voipCustom
        }
    }
}
