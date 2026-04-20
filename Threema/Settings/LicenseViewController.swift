import ThreemaMacros

final class LicenseViewController: SettingsWebViewViewController {

    private let licenseFileName = "license"

    // MARK: - Lifecycle
    
    init() {
        super.init(title: #localize("settings_list_license_title"))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTraitRegistration()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        webView.backgroundColor = Colors.backgroundViewController
                
        let baseURL = URL(fileURLWithPath: Bundle.main.bundlePath)
        if let myHtml = loadHTML() {
            webView.loadHTMLString(myHtml, baseURL: baseURL)
        }
    }

    private func setupTraitRegistration() {
        let traits: [UITrait] = [UITraitUserInterfaceStyle.self]
        registerForTraitChanges(traits) { [weak self] (_: Self, previous) in
            guard let self else {
                return
            }
            if previous.userInterfaceStyle != traitCollection.userInterfaceStyle {
                let baseURL = URL(fileURLWithPath: Bundle.main.bundlePath)
                if let myHtml = loadHTML() {
                    webView.loadHTMLString(myHtml, baseURL: baseURL)
                }
            }
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
        case .light:
            break
        }
        
        htmlString = htmlString?.replacingOccurrences(
            of: "/*threemalicensetoyear*/",
            with: DateFormatter.getYear(for: Date())
        )
        
        return htmlString
    }
}
