//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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
import MBProgressHUD
import WebKit

class ThreemaWorkViewController: ThemedViewController {
    
    var webView: WKWebView?
    
    override var shouldAutorotate: Bool {
        true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .all
        }
        return .allButUpsideDown
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Colors.backgroundViewController
               
        webView = WKWebView(frame: view.frame)
        webView!.allowsLinkPreview = false
        webView!.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView!.navigationDelegate = self
        webView!.isOpaque = false
        
        view.addSubview(webView!)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
            
        let lang = Bundle.main.preferredLocalizations.first ?? "en"
        let version = AppInfo.appVersion.version ?? "-"
        
        let theme: String
        switch Colors.theme {
        case .dark:
            theme = "dark"
        case .light, .undefined:
            theme = "light"
        }
                
        let urlString = "https://threema.ch/work_info/?lang=\(lang)&version=\(version)&platform=ios&theme=\(theme)"
        let threemaWorkURL = URL(string: urlString)!
        
        MBProgressHUD.showAdded(to: view, animated: true)
        let request = URLRequest(url: threemaWorkURL, cachePolicy: .reloadIgnoringCacheData)
        webView!.load(request)
    }
}

// MARK: - WKNavigationDelegate

extension ThreemaWorkViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        MBProgressHUD.hide(for: view, animated: true)
    }
    
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if navigationAction.navigationType == .linkActivated {
            if navigationAction.request.url != nil {
                UIApplication.shared.open(navigationAction.request.url!, options: [:], completionHandler: nil)
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }
}
