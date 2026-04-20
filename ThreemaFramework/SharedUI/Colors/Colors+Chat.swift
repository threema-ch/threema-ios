import Foundation
import UIKit

extension Colors {
    
    public class var backgroundChatLines: UIColor {
        switch theme {
        case .light:
            UIColor(resource: .gray500)
        case .dark:
            UIColor(resource: .gray450)
        }
    }
    
    public class func backgroundChatLines(colorTheme: Theme) -> UIColor {
        switch colorTheme {
        case .light:
            UIColor(resource: .gray500)
        case .dark:
            UIColor(resource: .gray450)
        }
    }
            
    public class var backgroundChatBar: UIColor {
        switch theme {
        case .light:
            UIColor(resource: .gray100)
        case .dark:
            UIColor(resource: .gray900)
        }
    }
    
    public class var chatBarInput: UIColor {
        switch theme {
        case .light:
            .white
        case .dark:
            UIColor(resource: .gray1000)
        }
    }
    
    public class var messageFailed: UIColor {
        .systemRed
    }
        
    public class var thumbnailProgressViewColor: UIColor {
        switch theme {
        case .light:
            UIColor(resource: .gray30)
        case .dark:
            UIColor(resource: .gray850)
        }
    }
    
    public class var chatReactionBubble: UIColor {
        switch theme {
        case .light:
            UIColor(resource: .gray300)
        case .dark:
            UIColor(resource: .gray800)
        }
    }
    
    public class var chatReactionBubbleSelected: UIColor {
        switch theme {
        case .light:
            UIColor(resource: .gray400)
        case .dark:
            UIColor(resource: .gray550)
        }
    }

    public class var chatReactionBubbleHighlighted: UIColor {
        switch theme {
        case .light:
            UIColor(resource: .gray350)
        case .dark:
            UIColor(resource: .gray500)
        }
    }
    
    public class var chatReactionBubbleTextColor: UIColor {
        switch theme {
        case .light:
            UIColor(resource: .gray750)
        case .dark:
            UIColor(resource: .gray400)
        }
    }
    
    public class var chatReactionBubbleBorder: UIColor {
        UIColor.systemBackground
    }
}
