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

import CocoaLumberjackSwift
import JDStatusBarNotification
import MBProgressHUD
import SafariServices
import ThreemaFramework
import ThreemaMacros
import UIKit
@preconcurrency import WebKit

@objc class SettingsWebViewViewController: ThemedViewController {
    
    // MARK: - Public property

    private(set) lazy var webView: WKWebView = {
        let webPagePreferences = WKWebpagePreferences()
        webPagePreferences.allowsContentJavaScript = allowsContentJavaScript
        
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.defaultWebpagePreferences = webPagePreferences
        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.allowsLinkPreview = false
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.isOpaque = false
        
        return webView
    }()
    
    // MARK: - Private properties

    private var url: URL?
    private var isSetupWizard = false
    private var allowsContentJavaScript = false
    private var loadingPresenter: NotificationPresenter?
    
    // MARK: - Lifecycle
    
    /// Show content of a website in a webView
    /// - Parameters:
    ///   - url: URL of the content
    ///   - title: Title of the controller
    ///   - allowsContentJavaScript: The default value of this property is false. If you change the value to true, the
    /// web view execute JavaScript code referenced by the web content.
    ///   - isSetupWizard: If true, it will set all to dark mode
    @objc init(
        url: URL? = nil,
        title: String,
        allowsContentJavaScript: Bool = false,
        isSetupWizard: Bool = false
    ) {
        self.url = url
        self.allowsContentJavaScript = allowsContentJavaScript
        self.isSetupWizard = isSetupWizard
        
        super.init(nibName: nil, bundle: nil)
        
        self.title = title
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Colors.backgroundViewController
        
        webView.navigationDelegate = self
        view = webView
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        webView.backgroundColor = isSetupWizard ? Colors.backgroundWizard : Colors.backgroundViewController
        
        loadURL()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        loadingPresenter?.dismiss(animated: false)
    }
    
    // MARK: Configurations
    
    override var shouldAutorotate: Bool {
        true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .allButUpsideDown
    }
    
    // MARK: - Private functions
    
    /// Begin loading the URL if it has been set. If the loading process takes more than 0.8 seconds, a loading
    /// indicator will be displayed.
    private func loadURL() {
        guard let url,
              let combinedURL = appendQueryItems(to: url) else {
            DDLogError("Can't load url, because url is empty")
            return
        }
        
        Task.detached {
            try? await Task.sleep(seconds: 0.8)
            
            Task { @MainActor in
                if self.webView.isLoading {
                    NotificationPresenterWrapper.shared.presentIndefinitely(type: .loadingWebSite) { presenter in
                        if self.webView.isLoading {
                            self.loadingPresenter = presenter
                        }
                        else {
                            presenter.dismiss()
                        }
                    }
                }
            }
        }
        
        let request = URLRequest(url: combinedURL, cachePolicy: .reloadIgnoringCacheData)
        webView.load(request)
    }
    
    /// Append the query parameters ‘lang’, ‘version’, ‘platform’, and ‘theme’.
    /// If the ‘isSetupWizard’ parameter is true, the dark theme will always be selected.
    /// - Parameter url: URL to append the items
    /// - Returns: URL?
    private func appendQueryItems(to url: URL) -> URL? {
        let theme: String = {
            guard !self.isSetupWizard else {
                return "dark"
            }
            switch Colors.theme {
            case .dark:
                return "dark"
            case .light, .undefined:
                return "light"
            }
        }()
        
        if #available(iOS 16.0, *) {
            return url.appending(queryItems: [
                URLQueryItem(name: "lang", value: Bundle.main.preferredLocalizations.first ?? "en"),
                URLQueryItem(name: "version", value: AppInfo.appVersion.version ?? "-"),
                URLQueryItem(name: "platform", value: "ios"),
                URLQueryItem(name: "theme", value: theme),
            ])
        }
        else {
            let lang = Bundle.main.preferredLocalizations.first ?? "en"
            let version = AppInfo.appVersion.version ?? "-"
            
            let urlString = "\(url.absoluteString)?lang=\(lang)&version=\(version)&platform=ios&theme=\(theme)"
            return URL(string: urlString)
        }
    }
    
    /// Check and add SUPPORT as contact and open the chat with it.
    private func addSupportContactAndOpenChat() {
        ContactStore.shared()
            .addContact(
                with: "*SUPPORT",
                verificationLevel: Int32(ContactEntity.VerificationLevel.fullyVerified.rawValue),
                onCompletion: { contact, _ in
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
                },
                onError: { error in
                    DDLogError("\(error)")
                }
            )
    }
}

// MARK: - Notifications

extension SettingsWebViewViewController {
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        guard traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle else {
            return
        }
        
        loadURL()
    }
}

// MARK: - WKNavigationDelegate

extension SettingsWebViewViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
        loadingPresenter?.dismiss()
    }
    
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
            if let scheme = url.scheme, scheme.hasPrefix("http") || scheme.hasPrefix("https") {
                let config = SFSafariViewController.Configuration()
                let safariView = SFSafariViewController(url: url, configuration: config)
                present(safariView, animated: true)
            }
            else {
                if let host = url.host,
                   host == "compose",
                   let query = url.query,
                   query.hasPrefix("id=*SUPPORT") {
                    addSupportContactAndOpenChat()
                }
                else {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: Error) {
        loadingPresenter?.dismiss()
        NotificationPresenterWrapper.shared.present(type: .noConnection)
    }
    
    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation?,
        withError error: any Error
    ) {
        loadingPresenter?.dismiss()
        if (error as NSError).code == URLError.Code.notConnectedToInternet.rawValue {
            NotificationPresenterWrapper.shared.present(type: .noConnection)
        }
    }
}
