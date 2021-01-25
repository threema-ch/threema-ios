//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020 Threema GmbH
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
import WebKit
import MBProgressHUD

class ThreemaWorkViewController: ThemedViewController {
    
    var webView: WKWebView?
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .all
        }
        return .allButUpsideDown
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = Colors.background()
        
        webView = WKWebView.init(frame: view.frame)
        webView!.allowsLinkPreview = false
        webView!.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView!.navigationDelegate = self
        webView!.isOpaque = false
        
        view.addSubview(webView!)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
            
        var lang:String? = Bundle.main.preferredLocalizations.first
        if lang == nil {
            lang = "en";
        }
        
        var version = BundleUtil.mainBundle().object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let suffix = BundleUtil.mainBundle().object(forInfoDictionaryKey: "ThreemaVersionSuffix") as? String
        if suffix != nil {
            version = version.appending(suffix!)
        }
        
        var theme:String! = ""
        switch Colors.getTheme() {
        case ColorThemeDark, ColorThemeDarkWork:
            theme = "dark"
            break
        case ColorThemeUndefined, ColorThemeLight, ColorThemeLightWork:
            theme = "light"
            break
        default:
            theme = "light"
            break
        }
                
        let urlString:String = String(format:"https://threema.ch/work_info/?lang=%@&version=%@&platform=ios&theme=%@", lang!, version, theme)
        let threemaWorkUrl:URL = URL(string: urlString)!
        
        MBProgressHUD.showAdded(to: view, animated: true)
        let request = URLRequest.init(url: threemaWorkUrl, cachePolicy: .reloadIgnoringCacheData)
        webView!.load(request)
    }
}

extension ThreemaWorkViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        MBProgressHUD.hide(for: view, animated: true)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
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
