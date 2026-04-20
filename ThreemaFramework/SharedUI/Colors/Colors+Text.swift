import Foundation

extension Colors {
    @objc public class var textSetup: UIColor {
        .white
    }
    
    @objc public class var textLockScreen: UIColor {
        .white
    }
    
    @objc public class var textInverted: UIColor {
        switch theme {
        case .light:
            .white
        case .dark:
            .black
        }
    }
    
    @objc public class var textLink: UIColor {
        .primary
    }
    
    @objc public class var textMentionMe: UIColor {
        textInverted
    }
    
    @objc public class var textMentionMeOwnMessage: UIColor {
        textInverted
    }
    
    @objc public class var textMentionMeOverviewMessage: UIColor {
        textInverted
    }
    
    @objc public class var textWizardLink: UIColor {
        .primary
    }
    
    @objc public class var textProminentButton: UIColor {
        switch TargetManager.current {
        case .threema, .green:
            .prominentButtonTextPrivate
        case .work, .blue:
            .prominentButtonTextWork
        case .onPrem:
            .prominentButtonTextOnPrem
        case .customOnPrem:
            .prominentButtonTextCustomOnPrem
        }
    }
    
    @objc public class var textProminentButtonWizard: UIColor {
        textProminentButton.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
    }
}
