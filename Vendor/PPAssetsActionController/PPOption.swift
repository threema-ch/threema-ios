import UIKit

/**
 Representation of an action that can be taken when tapping a button
 on PPOptionsViewController.
 */
public struct PPOption {
    
    /// Title to be shown on a button
    let title: String
    
    /// Action that will be executed when user selects the option.
    let handler: () -> ()
    
    let icon: UIImage?

    public init(withTitle title: String, withIcon icon: UIImage?, handler: @escaping () -> ()) {
        self.title = title
        self.handler = handler
        self.icon = icon
    }
}
