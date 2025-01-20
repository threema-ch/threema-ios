//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2025 Threema GmbH
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

import CocoaLumberjackSwift
import Foundation
import ThreemaMacros
import UIKit

@objc class IDNASafetyHelper: NSObject {
    @objc class func safeOpen(url: URL, viewController: UIViewController) {
        if url.isIDNASafe {
            if url.host?.lowercased() == "threema.id" {
                URLHandler.handleThreemaDotIDURL(url, hideAppChooser: false)
            }
            else {
                UIApplication.shared.open(url as URL, options: [:], completionHandler: nil)
            }
        }
        else {
            showAlert(url: url, viewController: viewController)
        }
    }
    
    class func isLegalURL(url: URL, viewController: UIViewController) -> Bool {
        guard url.isIDNASafe else {
            showAlert(url: url, viewController: viewController)
            return false
        }
        return true
    }
    
    private class func showAlert(url: URL, viewController: UIViewController) {
        let body = String.localizedStringWithFormat(
            #localize("url_warning_body"),
            url.host!.idnaDecoded!,
            url.host!
        )
        let alert = UIAlertController(
            title: #localize("url_warning_title"),
            message: body,
            preferredStyle: .alert
        )
        alert
            .addAction(UIAlertAction(
                title: #localize("ok"),
                style: .default,
                handler: { _ in
                    UIApplication.shared.open(url as URL, options: [:], completionHandler: nil)
                }
            ))
        alert
            .addAction(UIAlertAction(
                title: #localize("cancel"),
                style: .cancel,
                handler: nil
            ))
        
        viewController.present(alert, animated: true)
    }
}
