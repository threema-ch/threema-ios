import Foundation
import ThreemaMacros
import UIKit

extension UIBarButtonItem {
    public static func cancelButton(title: String? = nil, target: Any, selector: Selector) -> UIBarButtonItem {
        if #available(iOS 26.0, *) {
            UIBarButtonItem(
                barButtonSystemItem: .cancel,
                target: target,
                action: selector
            )
        }
        else {
            UIBarButtonItem(
                title: title ?? #localize("cancel"),
                style: .plain,
                target: target,
                action: selector
            )
        }
    }

    /// For iOS 26 and later we use `.done` to get a small button with a checkmark
    public static func saveButton(target: Any, selector: Selector) -> UIBarButtonItem {
        if #available(iOS 26.0, *) {
            UIBarButtonItem(
                barButtonSystemItem: .done,
                target: target,
                action: selector
            )
        }
        else {
            UIBarButtonItem(
                barButtonSystemItem: .save,
                target: target,
                action: selector
            )
        }
    }
    
    public static func closeButton(target: Any, selector: Selector) -> UIBarButtonItem {
        if #available(iOS 26.0, *) {
            UIBarButtonItem(
                barButtonSystemItem: .close,
                target: target,
                action: selector
            )
        }
        else {
            UIBarButtonItem(
                barButtonSystemItem: .done,
                target: target,
                action: selector
            )
        }
    }

    public static func sendButton(target: Any, selector: Selector) -> UIBarButtonItem {
        if #available(iOS 26.0, *) {
            let image = UIImage(systemName: "arrow.up")?
                .withTintColor(.labelInverted, renderingMode: .alwaysOriginal)
            let item = UIBarButtonItem(
                image: image,
                style: .prominent,
                target: target,
                action: selector
            )
            return item
        }
        else {
            return UIBarButtonItem(
                title: #localize("send"),
                style: .done,
                target: target,
                action: selector
            )
        }
    }

    public static func editButton(target: Any, selector: Selector) -> UIBarButtonItem {
        if #available(iOS 26.0, *) {
            UIBarButtonItem(
                image: UIImage(systemName: "pencil"),
                style: .plain,
                target: target,
                action: selector
            )
        }
        else {
            UIBarButtonItem(
                title: #localize("edit"),
                style: .plain,
                target: target,
                action: selector
            )
        }
    }
    
    @objc public static func nextButton(target: Any, selector: Selector) -> UIBarButtonItem {
        if #available(iOS 26.0, *) {
            UIBarButtonItem(
                image: UIImage(systemName: "arrow.forward"),
                style: .plain,
                target: target,
                action: selector
            )
        }
        else {
            UIBarButtonItem(
                title: #localize("next"),
                style: .plain,
                target: target,
                action: selector
            )
        }
    }
}
