//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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

import ThreemaMacros

class LicenseViewController: SettingsWebViewViewController {

    private let licenseFileName = "license"
    
    // MARK: - Lifecycle
    
    init() {
        super.init(title: #localize("settings_list_license_title"))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        webView.backgroundColor = Colors.backgroundViewController
                
        let baseURL = URL(fileURLWithPath: Bundle.main.bundlePath)
        if let myHtml = loadHTML() {
            webView.loadHTMLString(myHtml, baseURL: baseURL)
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        guard traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle else {
            return
        }
         
        let baseURL = URL(fileURLWithPath: Bundle.main.bundlePath)
        if let myHtml = loadHTML() {
            webView.loadHTMLString(myHtml, baseURL: baseURL)
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadHTML() -> String? {
        guard let licenseFilePath = BundleUtil.path(forResource: licenseFileName, ofType: "html") else {
            return nil
        }
        
        var htmlString = try? String(contentsOfFile: licenseFilePath, encoding: .utf8)
        
        switch Colors.theme {
        case .dark:
            htmlString = htmlString?.replacingOccurrences(
                of: "/*backgroundcolor*/background-color: white;/*backgroundcolor*/",
                with: "background-color: #333"
            )
            htmlString = htmlString?.replacingOccurrences(
                of: "/*fontcolor*/color: black;/*fontcolor*/",
                with: "color: white"
            )
            htmlString = htmlString?.replacingOccurrences(
                of: "/*titlefontcolor*/color: #555;/*titlefontcolor*/",
                with: "color: #CCC;"
            )
            htmlString = htmlString?.replacingOccurrences(
                of: "/*titlefontcolor*/color: #777;/*titlefontcolor*/",
                with: "color: #AAA;"
            )
        case .light, .undefined:
            break
        }
        
        htmlString = htmlString?.replacingOccurrences(
            of: "/*threemalicensetoyear*/",
            with: DateFormatter.getYear(for: Date())
        )
        
        return htmlString
    }
}
