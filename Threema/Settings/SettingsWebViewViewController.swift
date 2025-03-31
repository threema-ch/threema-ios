//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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

import MBProgressHUD
import ThreemaFramework
import ThreemaMacros
import UIKit
import WebKit

class SettingsWebViewViewController: UIViewController, WKNavigationDelegate {
    
    var webView: WKWebView!
    
    var url: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Colors.backgroundViewController
        
        let webPreferences = WKPreferences()
        webPreferences.javaScriptEnabled = false
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.preferences = webPreferences
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.allowsLinkPreview = false
        webView.navigationDelegate = self
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView!.isOpaque = false
        view = webView
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        webView.backgroundColor = Colors.backgroundViewController
        
        let lang = Bundle.main.preferredLocalizations.first ?? "en"
        let version = AppInfo.appVersion.version ?? "-"
        
        var theme =
            switch Colors.theme {
            case .dark:
                "dark"
            case .light, .undefined:
                "light"
            }
        
        if navigationController?.viewControllers.count == 1 {
            let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(donePressed))
            navigationItem.rightBarButtonItem = doneButton
            theme = "dark"
            webView.backgroundColor = Colors.backgroundWizard
            navigationController?.navigationBar.barStyle = .black
            navigationController?.navigationBar.isTranslucent = true
            navigationController?.navigationBar.tintColor = .primary
            
            navigationController?.navigationBar.overrideUserInterfaceStyle = .dark
        }
        
        guard let url else {
            fatalError()
        }
        
        let urlString = "\(url)?lang=\(lang)&version=\(version)&platform=ios&theme=\(theme)"
        let fullURL = URL(string: urlString)!
        
        MBProgressHUD.showAdded(to: view, animated: true)
        let request = URLRequest(url: fullURL, cachePolicy: .reloadIgnoringCacheData)
        webView.load(request)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        MBProgressHUD.hide(for: view, animated: true)
    }
    
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        MBProgressHUD.hide(for: view, animated: true)
        UIAlertTemplate.showAlert(
            owner: self,
            title: #localize("cannot_connect_title"),
            message: #localize("cannot_connect_message")
        ) { _ in
            self.navigationController?.dismiss(animated: true, completion: nil)
        }
    }
    
    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: any Error
    ) {
        MBProgressHUD.hide(for: webView, animated: true)
        if (error as NSError).code == URLError.Code.notConnectedToInternet.rawValue {
            NotificationPresenterWrapper.shared.present(type: .noConnection)
        }
    }
    
    override var shouldAutorotate: Bool {
        true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .allButUpsideDown
    }
    
    @objc func donePressed() {
        navigationController?.dismiss(animated: true, completion: nil)
    }
}
