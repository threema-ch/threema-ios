import CocoaLumberjackSwift
import Foundation
import ThreemaMacros
import UIKit

class IDNASafetyHelper: NSObject {
    class func safeOpen(url: URL, viewController: UIViewController) {
        if url.isIDNASafe {
            if url.host?.lowercased() == "threema.id" {
                URLHandler().handle(url)
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
