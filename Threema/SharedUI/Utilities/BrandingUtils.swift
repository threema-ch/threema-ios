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
    
    private enum LogoType {
        case `default`(UIImage?)
        case custom(UIImage?)
        
        var height: CGFloat {
            switch self {
            case .default:
                return BrandingUtils.defaultLogoHeight
            case .custom:
                return BrandingUtils.customLogoHeight
            }
        }
        
        var image: UIImage? {
            switch self {
            case let .default(image):
                return image
            case let .custom(image):
                return image
            }
        }
    }
    
    @objc public static func updateTitleLogo(in navController: UINavigationController?) {
        guard let navController, let navItem = navController.topViewController?.navigationItem else {
            return
        }
        
        updateTitleLogo(of: navItem, in: navController)
    }
    
    @objc public static func updateTitleLogo(of navItem: UINavigationItem?, in navController: UINavigationController?) {
        guard let navItem,
              let navController else {
            return
        }
        
        Task {
            let logo = await self.logo()
            
            await MainActor.run {
                setLogo(logo, of: navItem, navigationController: navController)
            }
        }
    }
    
    private static func setLogo(
        _ logoType: LogoType,
        of navigationItem: UINavigationItem,
        navigationController: UINavigationController
    ) {
        guard let logo = logoType.image else {
            return
        }
        
        // Size
        var height: CGFloat = logoType.height
        var hasCorrectSize = false
        var totalFreeWidth: CGFloat = navigationController.navigationBar.frame.width
        var frame = CGRect.zero
        
        // Subtract NavbarItems
        navigationItem.leftBarButtonItems.map { totalFreeWidth -= $0.reduce(0) { $0 + $1.width } }
        navigationItem.rightBarButtonItems.map { totalFreeWidth -= $0.reduce(0) { $0 + $1.width } }
    
        // Scale
        while !hasCorrectSize, height > 0 {
            let width: CGFloat = height * logo.size.width / logo.size.height

            if totalFreeWidth - totalVerticalSafeArea > width {
                hasCorrectSize = true
                frame = CGRect(x: 0.0, y: 0.0, width: width, height: height)
            }
            else {
                height -= 2
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
            navigationItem.titleView = wrapView
        }
    }
    
    private static func logo() async -> LogoType {
        await withCheckedContinuation { continuation in
            if LicenseStore.requiresLicenseKey(), let logoURLString = Colors.licenseLogoURL {
                // Not consumer and has logoURL
                guard let logoURL = URL(string: logoURLString) else {
                    DDLogError("Generating logo URL failed")
                    return
                }
                
                SDWebImageManager.shared.loadImage(with: logoURL, progress: nil) { image, _, error, _, _, _ in
                    error.map { DDLogError("Loading logo failed: \($0)") }
                    continuation.resume(returning: .custom(image))
                }
            }
            else {
                continuation.resume(returning: .default(Colors.threemaLogo))
            }
        }
    }
}
