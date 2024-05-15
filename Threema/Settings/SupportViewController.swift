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
import MBProgressHUD
import SafariServices
import WebKit

class SupportViewController: UIViewController {
    
    private var webView: WKWebView!
    private var myIdentity = BusinessInjector().myIdentityStore
    
    // MARK: - Lifecycle
    
    override func loadView() {
        let webConfiguration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = self
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeChanged),
            name: Notification.Name(kNotificationColorThemeChanged),
            object: nil
        )

        // Set correct navigation bar edge appearance
        themeChanged()
        
        if let myURL = createURL() {
            let myRequest = URLRequest(url: myURL)
            webView.load(myRequest)
            MBProgressHUD.showAdded(to: webView, animated: true)
        }
        else {
            DDLogError("Url could neither be found nor created")
            searchContact()
        }
    }
    
    // MARK: - Helper methods
    
    func createURL() -> URL? {
        if let licenseURL = myIdentity.licenseSupportURL, let url = URL(string: licenseURL), !licenseURL.isEmpty {
            let supportURL = url
            return supportURL
        }
        else {
            var queryItems = [URLQueryItem]()
            queryItems.append(URLQueryItem(name: "lang", value: Bundle.main.preferredLocalizations[0]))
            queryItems.append(URLQueryItem(name: "version", value: ThreemaUtility.clientVersion))
            queryItems.append(URLQueryItem(name: "identity", value: myIdentity.identity))
            queryItems.append(URLQueryItem(name: "theme", value: Colors.theme == .dark ? "dark" : "light"))
            guard let urlComp = BundleUtil.object(forInfoDictionaryKey: "ThreemaSupportURL") as? String else {
                return nil
            }
            var components = URLComponents(string: urlComp)
            components?.queryItems = queryItems
            return components?.url
        }
    }
    
    func searchContact() {
        ContactStore.shared()
            .addContact(
                with: "*SUPPORT",
                verificationLevel: Int32(kVerificationLevelUnverified),
                onCompletion: { contact, _ in
                    self.moveToSupportChat(contact: contact!)
                },
                onError: { error in
                    DDLogError("\(error)")
                }
            )
    }
    
    func moveToSupportChat(contact: ContactEntity) {
        let message = "My app version: \(ThreemaUtility.clientVersionWithMDM)"
        let info = [
            kKeyContact: contact,
            kKeyForceCompose: NSNumber(value: true),
            kKeyText: message,
        ] as [String: Any]
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name(rawValue: kNotificationShowConversation),
                object: nil,
                userInfo: info
            )
        }
    }
    
    func showWebsite(_ url: URL) {
        let config = SFSafariViewController.Configuration()
        let safariView = SFSafariViewController(url: url, configuration: config)
        present(safariView, animated: true)
    }
    
    @objc private func themeChanged() {
        navigationItem.scrollEdgeAppearance = Colors.theme == .dark ? Colors.defaultNavigationBarAppearance() : Colors
            .transparentNavigationBarAppearance()
    }
}

// MARK: - WKNavigationDelegate

extension SupportViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        MBProgressHUD.hide(for: webView, animated: true)
    }
    
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        
        if let url = navigationAction.request.url, navigationAction.navigationType == .linkActivated {
            if let scheme = url.scheme, scheme.hasPrefix("http") || scheme.hasPrefix("https") {
                showWebsite(url)
            }
            else {
                searchContact()
            }
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}
