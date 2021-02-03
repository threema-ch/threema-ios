//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2021 Threema GmbH
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
import Punycode

@objc class IDNSafetyHelper: NSObject {
    @objc class func safeOpen(url: URL, viewController: UIViewController) {
        if (isLegalURL(url: url)) {
            if (url.host?.lowercased() == "threema.id") {
                URLHandler.handleThreemaDotIdUrl(url, hideAppChooser: false)
            } else {
                UIApplication.shared.open(url as URL, options: [:], completionHandler: nil)
            }
        } else {
            let body = String(format: NSLocalizedString("url_warning_body", comment: ""), url.host!.idnaDecoded!, url.host!)
            let alert = UIAlertController(title: NSLocalizedString("url_warning_title", comment: ""), message: body, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: { action in 
                UIApplication.shared.open(url as URL, options: [:], completionHandler: nil)
            }))
            alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel, handler: nil))
            
            viewController.present(alert, animated: true)
        }
    }
    
    @objc class func isLegalURL(url: URL) -> Bool {
        let legalHostnamePattern = try! NSRegularExpression(pattern: "^(([\\x00-\\x7F]*)|([^\\x00-\\x7F]*))$")
        let strippedHost = url.host?.idnaDecoded?.replacingOccurrences(of: ".", with: "")
        
        if (strippedHost != nil) {
            return (legalHostnamePattern.numberOfMatches(in: strippedHost!, range: NSRange(location: 0, length: strippedHost!.utf16.count)) > 0)
        } else {
            return true
        }
    }
}
