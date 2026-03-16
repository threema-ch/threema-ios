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

import SwiftUI
import UIKit

extension UIWindow {
        
    private static var isSecureKey: UInt8 = 0
    
    /// Tracks whether this specific window instance has already been secured.
    /// Using an associated object (rather than a static flag) ensures the state
    /// is tied to each `UIWindow` instance individually — so repeated calls on
    /// the same window are safely ignored, while a newly created replacement
    /// window starts unsecured and can be secured fresh.
    private var isSecure: Bool {
        get { objc_getAssociatedObject(self, &Self.isSecureKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &Self.isSecureKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    @objc public func makeSecure() {
        guard TargetManager.isBusinessApp, MDMSetup().disableScreenshots(), !isSecure else {
            return
        }

        isSecure = true

        let field = SecureTextField()
        field.isSecureTextEntry = true

        let hostingController = UIHostingController(rootView: ScreenshotPreventionView())
        hostingController.view.backgroundColor = .clear

        field.leftView = hostingController.view
        field.leftViewMode = .always
        field.semanticContentAttribute = .forceLeftToRight

        addSubview(field)
        layer.superlayer?.addSublayer(field.layer)
        field.layer.sublayers?.last?.addSublayer(layer)
    }

    private class SecureTextField: UITextField {
        override func leftViewRect(forBounds bounds: CGRect) -> CGRect {
            UIScreen.main.bounds
        }
    }
}
