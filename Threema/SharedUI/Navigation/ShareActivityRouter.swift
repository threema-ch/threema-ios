//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

import UIKit

protocol ShareActivityRouting: AnyObject {
    var rootViewController: UIViewController { get }
    
    func present(items: [Any], sourceView: UIView?)
}

extension ShareActivityRouting {
    /// Presents a share activity with the given items from the given source view
    /// - Parameters:
    ///   - items: Items to be forwarded to `UIActivityViewController`
    ///   - sourceView: `UIView` acting as popover source
    func present(items: [Any], sourceView: UIView?) {
        let activityViewController = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        activityViewController.popoverPresentationController?.sourceView = sourceView
        rootViewController.present(activityViewController, animated: true)
    }
}

final class ShareActivityRouter: ShareActivityRouting {
    let rootViewController: UIViewController
    
    init(rootViewController: UIViewController) {
        self.rootViewController = rootViewController
    }
}
