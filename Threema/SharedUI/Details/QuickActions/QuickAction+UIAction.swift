import UIKit

@objc protocol LegacyUIActionProvider: AnyObject {
    func uiActions(in viewController: UIViewController) -> NSArray // of UIAction
}

extension QuickAction {
    var asUIAction: UIAction {
        // Use non-filled version of icon if declared as such in name string
        let actionImageName = imageNameProvider().replacingOccurrences(of: ".fill", with: "")
        let actionImage = BundleUtil.imageNamed(actionImageName)
        assert(
            actionImage != nil,
            "As this only supports iOS 13 and up we assume that at least an SF Symbol exists for the image"
        )
        
        return UIAction(
            title: title,
            image: actionImage,
            handler: action
        )
    }
}

// MARK: - UIAction + QuickActionUpdate

// Support `QuickActionUpdate` for `UIAction` in `UIMenu`
extension UIAction: QuickActionUpdate {
    func reload() {
        // no-op: Because the menu will anyway disappear when the action is called
    }
    
    func hide() {
        // no-op: Because the menu will anyway disappear when the action is called
    }
    
    func popOverSourceView() -> UIView? {
        // `nil` Because the menu will anyway disappear when the action is called
        nil
    }
}
