import CocoaLumberjackSwift
import Foundation
import SDWebImage
import UIKit

public enum BrandingUtils {
    
    // Constants
    public static let compactNavBarHeight: CGFloat =
        if #available(iOS 26.0, *) {
            62
        }
        else {
            44
        }
    
    public static let compactPromptNavBarHeight: CGFloat =
        if #available(iOS 26.0, *) {
            88
        }
        else {
            72
        }
    
    static let defaultLogoHeight: CGFloat = 15.0
    static let customLogoHeight: CGFloat = 28.0
    static let totalVerticalSafeArea: CGFloat = 32
    
    private enum LogoType {
        case `default`(UIImage?)
        case custom(UIImage?)
        
        var height: CGFloat {
            switch self {
            case .default:
                BrandingUtils.defaultLogoHeight
            case .custom:
                BrandingUtils.customLogoHeight
            }
        }
        
        var image: UIImage? {
            switch self {
            case let .default(image):
                image
            case let .custom(image):
                image
            }
        }
    }
    
    public static func updateTitleLogo(in navController: UINavigationController?) {
        guard let navController, let navItem = navController.topViewController?.navigationItem else {
            return
        }
        
        updateTitleLogo(of: navItem, in: navController)
    }
    
    public static func updateTitleLogo(of navItem: UINavigationItem?, in navController: UINavigationController?) {
        guard let navItem,
              let navController else {
            return
        }
        
        Task {
            let logo = await logo()
            
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
        Task { @MainActor in
            UIView.performWithoutAnimation {
                navigationItem.titleView = wrapView
            }
        }
    }
    
    private static func logo() async -> LogoType {
        await withCheckedContinuation { continuation in
            guard TargetManager.isBusinessApp, let logoURLString = Colors.licenseLogoURL else {
                continuation.resume(returning: .default(Colors.threemaLogo))
                return
            }
            
            // Not consumer and has logoURL
            guard let logoURL = URL(string: logoURLString) else {
                DDLogError("Generating logo URL failed")
                return
            }
            
            SDWebImageManager.shared.loadImage(with: logoURL, progress: nil) { image, _, error, _, _, _ in
                error.map {
                    DDLogError("Loading logo failed: \($0)")
                }
                continuation.resume(returning: .custom(image))
            }
        }
    }
}
