import Foundation

extension Colors {
    @objc public class var separator: UIColor {
        switch theme {
        case .light:
            UIColor(resource: .gray400)
        case .dark:
            UIColor(resource: .gray750)
        }
    }
    
    @objc public class var backgroundTableView: UIColor {
        switch theme {
        case .light:
            UIColor(resource: .gray150)
        case .dark:
            .black
        }
    }
    
    @objc public class var plainBackgroundTableView: UIColor {
        switch theme {
        case .light:
            .white
        case .dark:
            .black
        }
    }
        
    @objc public class var backgroundTableViewCellSelected: UIColor {
        switch theme {
        case .light:
            UIColor(resource: .backgroundCellSelectedLight)
        case .dark:
            UIColor(resource: .backgroundCellSelectedDark)
        }
    }
}
