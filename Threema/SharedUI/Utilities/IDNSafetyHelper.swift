//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2022 Threema GmbH
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
import Punycode
import UIKit

@objc class IDNSafetyHelper: NSObject {
    @objc class func safeOpen(url: URL, viewController: UIViewController) {
        if isLegalURL(url: url) {
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
    
    @objc class func isLegalURL(url: URL) -> Bool {
        guard let legalHostnamePattern = try? NSRegularExpression(pattern: "^(([\\x00-\\x7F]*)|([^\\x00-\\x7F]*))$"),
              let strippedHost = url.host?.idnaDecoded?.replacingOccurrences(of: ".", with: "") else {
            DDLogWarn("Can't generate stripped host for \(url.absoluteString)")
            return true
        }
        
        return (legalHostnamePattern.numberOfMatches(
            in: strippedHost,
            range: NSRange(location: 0, length: strippedHost.utf16.count)
        ) > 0)
    }
    
    class func isLegalURL(url: URL, viewController: UIViewController) -> Bool {
        guard IDNSafetyHelper.isLegalURL(url: url) else {
            showAlert(url: url, viewController: viewController)
            return false
        }
        return true
    }
    
    private class func showAlert(url: URL, viewController: UIViewController) {
        let body = String(
            format: BundleUtil.localizedString(forKey: "url_warning_body"),
            url.host!.idnaDecoded!,
            url.host!
        )
        let alert = UIAlertController(
            title: BundleUtil.localizedString(forKey: "url_warning_title"),
            message: body,
            preferredStyle: .alert
        )
        alert
            .addAction(UIAlertAction(
                title: BundleUtil.localizedString(forKey: "ok"),
                style: .default,
                handler: { _ in
                    UIApplication.shared.open(url as URL, options: [:], completionHandler: nil)
                }
            ))
        alert
            .addAction(UIAlertAction(
                title: BundleUtil.localizedString(forKey: "cancel"),
                style: .cancel,
                handler: nil
            ))
        
        viewController.present(alert, animated: true)
    }
}
