//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2017-2021 Threema GmbH
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

import UIKit
import ThreemaFramework
import WebKit
import MBProgressHUD

class PrivacyPolicyViewController: UIViewController, WKNavigationDelegate {
    
    var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = Colors.background()

        let webPreferences = WKPreferences.init()
        webPreferences.javaScriptEnabled = false
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.preferences = webPreferences
        webView = WKWebView.init(frame: .zero, configuration: webConfiguration)
        webView.allowsLinkPreview = false
        webView.navigationDelegate = self
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView!.isOpaque = false
        view = webView
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        webView.backgroundColor = Colors.background()
        
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
        
        if self.navigationController?.viewControllers.count == 1 {
            let doneButton: UIBarButtonItem = UIBarButtonItem.init(barButtonSystemItem: .done, target:self, action:#selector(donePressed))
            self.navigationItem.rightBarButtonItem = doneButton
            theme = "dark"
            webView.backgroundColor = Colors.backgroundThemeDark()
            self.navigationController?.navigationBar.barStyle = .black
            self.navigationController?.navigationBar.isTranslucent = true
            self.navigationController?.navigationBar.tintColor = Colors.mainThemeDark()
        }
        
        let urlString:String = String(format:"https://threema.ch/privacy_policy/?lang=%@&version=%@&platform=ios&theme=%@", lang!, version, theme)
        let privacyUrl:URL = URL(string: urlString)!
        
        MBProgressHUD.showAdded(to: view, animated: true)
        let request = URLRequest.init(url: privacyUrl, cachePolicy: .reloadIgnoringCacheData)
        webView.load(request)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        MBProgressHUD.hide(for: view, animated: true)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated {
            if let url = navigationAction.request.url {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        MBProgressHUD.hide(for: view, animated: true)
        UIAlertTemplate.showAlert(owner: self, title: BundleUtil.localizedString(forKey: "cannot_connect_title"), message: BundleUtil.localizedString(forKey: "cannot_connect_message")) { (okAction) in
            self.navigationController?.dismiss(animated: true, completion: nil)
        }
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        return .allButUpsideDown
    }
    
    @objc func donePressed() {
        self.navigationController?.dismiss(animated: true, completion: nil)
    }
}

extension String {
    func hexadecimal() -> Data? {
        var data = Data(capacity: self.count / 2)
        
        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: self, range: NSMakeRange(0, utf16.count)) { match, flags, stop in
            let byteString = (self as NSString).substring(with: match!.range)
            var num = UInt8(byteString, radix: 16)!
            data.append(&num, count: 1)
        }
        
        guard data.count > 0 else { return nil }
        
        return data
    }
    
}

extension Data {
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }
    
    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
    }
}


