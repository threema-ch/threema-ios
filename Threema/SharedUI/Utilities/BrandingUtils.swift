//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2024 Threema GmbH
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
import SDWebImage
import UIKit

public class BrandingUtils: NSObject {
    
    // Constants
    @objc public static let compactNavBarHeight: CGFloat = 44
    @objc public static let compactPromptNavBarHeight: CGFloat = 78
    static let defaultLogoHeight: CGFloat = 15.0
    static let customLogoHeight: CGFloat = 28.0
    static let totalVerticalSafeArea: CGFloat = 32
    
    // Helpers
    static let helperImageView = UIImageView()

    @objc public static func updateTitleLogo(of navItem: UINavigationItem?, in navController: UINavigationController?) {
        
        guard let navItem,
              let navController else {
            return
        }
        
        if LicenseStore.requiresLicenseKey(), let logoURLString = Colors.licenseLogoURL {
            // Not consumer and has logoURL
            guard let logoURL = URL(string: logoURLString) else {
                DDLogError("Generating logo URL failed")
                return
            }
            
            // **Info**: The helper image view is used in a hackie fashion, just for calling the set image function, but is else never used. We use the image returned in the closure to then add it to the titleView.
            
            // Load Image and assign it
            helperImageView.sd_setImage(with: logoURL) { image, error, _, _ in
                if let error {
                    DDLogError("Loading logo failed: \(error)")
                    return
                }
                
                self.setLogo(of: navItem, in: navController, with: image, defaultLogo: false)
            }
        }
        else {
            // Consumer or no LogoURL
            setLogo(of: navItem, in: navController, with: Colors.threemaLogo, defaultLogo: true)
        }
    }
    
    private static func setLogo(
        of navItem: UINavigationItem,
        in navController: UINavigationController,
        with logo: UIImage?,
        defaultLogo: Bool
    ) {
        
        guard let logo else {
            return
        }
    
        // Size
        var height: CGFloat = defaultLogo ? defaultLogoHeight : customLogoHeight
        var hasCorrectSize = false
        var totalFreeWidth: CGFloat = navController.navigationBar.frame.width
        var frame = CGRect.zero
        
        // Subtract NavbarItems
        if let leftItems = navItem.leftBarButtonItems {
            for item in leftItems {
                totalFreeWidth -= item.width
            }
        }
        
        if let rightItems = navItem.rightBarButtonItems {
            for item in rightItems {
                totalFreeWidth -= item.width
            }
        }
        
        // Scale
        while !hasCorrectSize, height > 0 {
            let width: CGFloat = height * logo.size.width / logo.size.height

            if totalFreeWidth - totalVerticalSafeArea > width {
                hasCorrectSize = true
                frame = CGRect(x: 0.0, y: 0.0, width: width, height: height)
            }
            else {
                height = height - 2
            }
        }

        // Create ImageView
        let imageView = UIImageView(frame: frame)
        imageView.contentMode = .scaleAspectFit
        imageView.image = logo
        
        // Wrapping is still needed, otherwise scaling of image does not work properly
        let wrapView = UIView(frame: frame)
        wrapView.addSubview(imageView)
        
        // Add to NavBar
        DispatchQueue.main.async {
            navItem.titleView = wrapView
        }
    }
}
