//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2023 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import Foundation

@objc public class UIAlertTemplate: NSObject {
    @objc public static func showAlert(
        owner: UIViewController,
        title: String?,
        message: String?,
        actionOk: ((UIAlertAction) -> Void)? = nil
    ) {
        showAlert(owner: owner, title: title, message: message, titleOk: nil, actionOk: actionOk)
    }
    
    @objc public static func showAlert(
        owner: UIViewController,
        title: String?,
        message: String?,
        titleOk: String? = nil,
        actionOk: ((UIAlertAction) -> Void)? = nil
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let ok = titleOk ?? BundleUtil.localizedString(forKey: "ok")
        alert
            .addAction(UIAlertAction(
                title: ok,
                style: .default,
                handler: actionOk
            ))
        
        owner.present(alert, animated: true)
    }
        
    @objc public static func showAlert(
        owner: UIViewController,
        title: String?,
        message: String?,
        titleOk: String,
        actionOk: ((UIAlertAction) -> Void)? = nil,
        titleCancel: String? = nil,
        actionCancel: ((UIAlertAction) -> Void)? = nil
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: titleOk, style: .default, handler: actionOk))
        
        let cancelTitle = resolveCancelTitle(with: titleCancel)
        alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel, handler: actionCancel))
        
        owner.present(alert, animated: true)
    }
    
    @objc public static func showDestructiveAlert(
        owner: UIViewController,
        title: String?,
        message: String?,
        titleDestructive: String,
        actionDestructive: @escaping ((UIAlertAction) -> Void),
        titleCancel: String? = nil,
        actionCancel: ((UIAlertAction) -> Void)? = nil
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let cancelTitle = resolveCancelTitle(with: titleCancel)
        alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel, handler: actionCancel))
        
        alert.addAction(UIAlertAction(title: titleDestructive, style: .destructive, handler: actionDestructive))
        
        owner.present(alert, animated: true)
    }
    
    public static func showConfirm(
        owner: UIViewController,
        popOverSource: UIView,
        title: String,
        message: String?,
        titleOk: String,
        actionOk: ((UIAlertAction) -> Void)? = nil,
        titleCancel: String,
        actionCancel: ((UIAlertAction) -> Void)? = nil
    ) {
        let confirm = UIAlertController(
            title: title,
            message: message,
            preferredStyle: UIAlertController.Style.actionSheet
        )
        confirm.addAction(UIAlertAction(title: titleCancel, style: .cancel, handler: actionCancel))
        confirm.addAction(UIAlertAction(title: titleOk, style: .destructive, handler: actionOk))
        let popOver = confirm.popoverPresentationController
        popOver?.sourceView = popOverSource
        popOver?.sourceRect = popOverSource.bounds
        popOver?.permittedArrowDirections = .any
        owner.present(confirm, animated: true)
    }
    
    public static func showConfirm(
        title: String,
        message: String? = nil,
        titleOk: String,
        on viewController: UIViewController,
        action: @escaping () -> Void
    ) {
        guard let view = viewController.view else {
            return
        }
        
        showConfirm(
            owner: viewController,
            popOverSource: view,
            title: title,
            message: message,
            titleOk: titleOk,
            actionOk: { _ in
                action()
            },
            titleCancel: "cancel".localized
        )
    }
    
    /// Show an action sheet
    ///
    /// See HIG for guidance: <https://developer.apple.com/design/human-interface-guidelines/ios/views/action-sheets/>
    ///
    /// - Parameters:
    ///   - owner: View Controller to present sheet on
    ///   - popOverSource: Origin view of sheet (i.e. table view cell, ...)
    ///   - title: Optional title shown in sheet
    ///   - message: Optional message shown in sheet
    ///   - actions: Actions shown in this order (put destructive actions at the beginning)
    ///   - cancelTitle: Custom title for cancel button (normally not needed)
    ///   - cancelAction: Custom action for cancel button
    public static func showSheet(
        owner: UIViewController,
        popOverSource: UIView,
        title: String? = nil,
        message: String? = nil,
        actions: [UIAlertAction],
        cancelTitle: String? = nil,
        cancelAction: ((UIAlertAction) -> Void)? = nil
    ) {
        
        // Because a title without a message gets formatted as a message, but a message without a
        // title like a title we switch them if we have no message.
        var title = title
        var message = message
        if message == nil {
            message = title
            title = nil
        }
        
        let actionSheet = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        actionSheet.popoverPresentationController?.sourceView = popOverSource
        actionSheet.popoverPresentationController?.sourceRect = popOverSource.bounds
        
        show(
            actionSheet: actionSheet,
            owner: owner,
            actions: actions,
            cancelTitle: cancelTitle,
            cancelAction: cancelAction
        )
    }
    
    /// Show an action sheet
    ///
    /// See HIG for guidance: <https://developer.apple.com/design/human-interface-guidelines/ios/views/action-sheets/>
    ///
    /// - Parameters:
    ///   - owner: View Controller to present sheet on
    ///   - popOverSource: Origin `UIBarButtonItem` of sheet
    ///   - title: Optional title shown in sheet
    ///   - message: Optional message shown in sheet
    ///   - actions: Actions shown in this order (put destructive actions at the beginning)
    ///   - cancelTitle: Custom title for cancel button (normally not needed)
    ///   - cancelAction: Custom action for cancel button
    public static func showSheet(
        owner: UIViewController,
        popOverSource: UIBarButtonItem,
        title: String? = nil,
        message: String? = nil,
        actions: [UIAlertAction],
        cancelTitle: String? = nil,
        cancelAction: ((UIAlertAction) -> Void)? = nil
    ) {
        
        // Because a title without a message gets formatted as a message, but a message without a
        // title like a title we switch them if we have no message.
        var title = title
        var message = message
        if message == nil {
            message = title
            title = nil
        }
        
        let actionSheet = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        actionSheet.popoverPresentationController?.barButtonItem = popOverSource
        
        show(
            actionSheet: actionSheet,
            owner: owner,
            actions: actions,
            cancelTitle: cancelTitle,
            cancelAction: cancelAction
        )
    }
    
    /// Show a custom alert with three actions
    ///
    /// See HIG for guidance: <https://developer.apple.com/design/human-interface-guidelines/ios/views/alerts/>
    ///
    /// - Warning: Try to not use it. Use two action alerts whenever possible.
    ///
    /// - Parameters:
    ///   - owner: View controller to present alert on
    ///   - title: Tile shown in alert
    ///   - message: Optional message shown in alert
    ///   - action1: First action
    ///   - action2: Second action
    ///   - cancelTitle: Custom title for cancel button (normally not needed)
    ///   - cancelAction: Custom action for cancel button
    public static func showAlert(
        owner: UIViewController,
        title: String,
        message: String? = nil,
        action1: UIAlertAction,
        action2: UIAlertAction,
        cancelTitle: String? = nil,
        cancelAction: ((UIAlertAction) -> Void)? = nil
    ) {
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alert.addAction(action1)
        alert.addAction(action2)
        
        let cancelTitle = resolveCancelTitle(with: cancelTitle)
        alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel, handler: cancelAction))
        
        owner.present(alert, animated: true)
    }
}

extension UIAlertTemplate {
    private static func resolveCancelTitle(with optionalTitle: String?) -> String {
        optionalTitle ?? BundleUtil.localizedString(forKey: "cancel")
    }
    
    // Internal helper for shared code
    private static func show(
        actionSheet: UIAlertController,
        owner: UIViewController,
        actions: [UIAlertAction],
        cancelTitle: String?,
        cancelAction: ((UIAlertAction) -> Void)?
    ) {
        for action in actions {
            actionSheet.addAction(action)
        }
        
        let cancelTitle = resolveCancelTitle(with: cancelTitle)
        actionSheet.addAction(UIAlertAction(title: cancelTitle, style: .cancel, handler: cancelAction))
        
        owner.present(actionSheet, animated: true)
    }
}
