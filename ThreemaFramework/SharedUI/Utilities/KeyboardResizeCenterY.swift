import Foundation

public final class KeyboardResizeCenterY {
    let parentView: UIView
    let resizeView: UIView
    var defaultCenterY: NSLayoutConstraint
    var offsetCenterY: NSLayoutConstraint?
    
    public init(parent: UIView, resize: UIView) {
        self.parentView = parent
        self.resizeView = resize
        
        self.defaultCenterY = NSLayoutConstraint(
            item: resizeView,
            attribute: NSLayoutConstraint.Attribute.centerY,
            relatedBy: NSLayoutConstraint.Relation.equal,
            toItem: parentView,
            attribute: NSLayoutConstraint.Attribute.centerY,
            multiplier: 1.0,
            constant: 0
        )
        
        parentView.addConstraint(defaultCenterY)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardDidShow),
            name: UIResponder.keyboardDidShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func keyboardDidShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?
            .cgRectValue {
            let offset: CGFloat = UIScreen.main.bounds.height - resizeView.frame.maxY - keyboardSize.height - 10
            if offset < 0 {
                offsetCenterY = NSLayoutConstraint(
                    item: resizeView,
                    attribute: NSLayoutConstraint.Attribute.centerY,
                    relatedBy: NSLayoutConstraint.Relation.equal,
                    toItem: parentView,
                    attribute: NSLayoutConstraint.Attribute.centerY,
                    multiplier: 1.0,
                    constant: offset
                )
                
                parentView.removeConstraint(defaultCenterY)
                parentView.addConstraint(offsetCenterY!)
            }
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        if let offsetCenterY {
            parentView.removeConstraint(offsetCenterY)
        }
        parentView.addConstraint(defaultCenterY)
    }
}
