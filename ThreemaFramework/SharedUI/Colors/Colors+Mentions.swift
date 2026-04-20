import Foundation

extension Colors {
    private class var backgroundMention: UIColor {
        switch theme {
        case .light:
            UIColor(resource: .gray400)
        case .dark:
            UIColor(resource: .gray500)
        }
    }
    
    private class var backgroundMentionOwnMessage: UIColor {
        switch theme {
        case .light:
            UIColor(resource: .gray400)
        case .dark:
            UIColor(resource: .gray600)
        }
    }
    
    private class var backgroundMentionOverviewMessage: UIColor {
        switch theme {
        case .light:
            UIColor(resource: .gray400)
        case .dark:
            UIColor(resource: .gray500)
        }
    }
    
    @objc public class var backgroundMentionMe: UIColor {
        switch theme {
        case .light:
            UIColor(resource: .gray600)
        case .dark:
            UIColor(resource: .gray400)
        }
    }
    
    @objc public class var backgroundMentionMeOwnMessage: UIColor {
        switch theme {
        case .light:
            UIColor(resource: .gray600)
        case .dark:
            UIColor(resource: .gray400)
        }
    }
    
    @objc public class var backgroundMentionMeOverviewMessage: UIColor {
        switch theme {
        case .light:
            UIColor(resource: .gray600)
        case .dark:
            UIColor(resource: .gray400)
        }
    }
}
