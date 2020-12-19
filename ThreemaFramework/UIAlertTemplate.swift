//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2020 Threema GmbH
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
    @objc public static func showAlert(owner: UIViewController, title: String?, message: String?, actionOk: ((UIAlertAction) -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: actionOk))
        owner.present(alert, animated: true, completion: nil);
    }
    
    @objc public static func showAlert(owner: UIViewController, title: String?, message: String?, actionOk: ((UIAlertAction) -> Void)? = nil, actionCancel: ((UIAlertAction) -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: actionOk))
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .default, handler: actionCancel))
        owner.present(alert, animated: true, completion: nil);
    }
    
    @objc public static func showAlert(owner: UIViewController, title: String?, message: String?, titleOk: String, actionOk: ((UIAlertAction) -> Void)? = nil, titleCancel: String, actionCancel: ((UIAlertAction) -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: titleOk, style: .default, handler: actionOk))
        alert.addAction(UIAlertAction(title: titleCancel, style: .default, handler: actionCancel))
        owner.present(alert, animated: true, completion: nil);
    }
    
    @objc public static func showDestructiveAlert(owner: UIViewController, title: String?, message: String?, titleDestructive: String, actionDestructive: ((UIAlertAction) -> Void)? = nil, titleCancel: String, actionCancel: ((UIAlertAction) -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: titleCancel, style: .cancel, handler: actionCancel))
        alert.addAction(UIAlertAction(title: titleDestructive, style: .destructive, handler: actionDestructive))
        owner.present(alert, animated: true, completion: nil);
    }
        
    public static func showConfirm(owner: UIViewController, popOverSource: UIView, title: String, message: String?, titleOk: String, actionOk: ((UIAlertAction) -> Void)? = nil, titleCancel: String, actionCancel: ((UIAlertAction) -> Void)? = nil) {
        let confirm = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.actionSheet)
        confirm.addAction(UIAlertAction(title: titleCancel, style: .cancel, handler: actionCancel))
        confirm.addAction(UIAlertAction(title: titleOk, style: .destructive, handler: actionOk))
        let popOver = confirm.popoverPresentationController
        popOver?.sourceView = popOverSource
        popOver?.sourceRect = popOverSource.bounds
        popOver?.permittedArrowDirections = .any
        owner.present(confirm, animated: true, completion: nil)
    }
    
    public static func showPicker(owner: UIViewController, title: String, message: String, options: [String: ((UIAlertAction) -> Void)?], titleCancel:String, actionCancel:((UIAlertAction) -> Void)? = nil) {
        
        let picker = UIAlertController(title: title, message: message, preferredStyle: .alert)
        options.forEach { (arg0) in
            
            let (key, action) = arg0
            picker.addAction(UIAlertAction(title: key, style: .default, handler: action))
        }
        picker.addAction(UIAlertAction(title: titleCancel, style: .cancel, handler: actionCancel))
        owner.present(picker, animated: true, completion: nil);
    }
}
