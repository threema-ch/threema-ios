import CocoaLumberjackSwift
import CommonCrypto
import SwiftUI
import ThreemaEssentials
import ThreemaFramework
import ThreemaMacros

final class URLHandler {
    
    private let businessInjector: any BusinessInjectorProtocol
    
    // MARK: Lifecycle

    required init(businessInjector: any BusinessInjectorProtocol) {
        self.businessInjector = businessInjector
    }
    
    convenience init() {
        self.init(businessInjector: BusinessInjector.ui)
    }
    
    // MARK: Public functions
    
    /// Function to handle the URL
    /// - Parameters:
    ///   - url: URL to handle
    ///   - hideAppChooser: Boolean to hide the app chooser if there are other targets installed. Default is `false`
    func handle(_ url: URL, hideAppChooser: Bool = false) {
        switch URLHandlerMapping.map(url) {
        case let .threemaDotID(url, targetIdentity):
            handleThreemaDotIDURL(
                url: url,
                targetIdentity: targetIdentity,
                hideAppChooser: hideAppChooser
            )
            
        case let .linkMobileNoCode(code):
            handleLinkMobileNo(code: code)
            
        case let .restore(query):
            Task { @MainActor [weak self] in
                self?.handleRestore(query)
            }
            
        case let .compose(query):
            handleCompose(query: query)
            
        case let .addIdentity(targetIdentity, query):
            addIdentity(targetIdentity, compose: query["text"] != nil, query: query)
            
        case let .license(query):
            URLHandler.handleLicense(licenseStore: businessInjector.licenseStore, query: query)
            
        case let .file(url):
            handleFile(url: url)
            
        case let .threemaLink(url):
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            
        case .unknown:
            DDLogError(
                "[URLHandler] Failed to handle URL: Unknown host (\(url.host() ?? "unknown")). Aborting URL handling."
            )
        }
    }
    
    /// Handle a license activation link outside of onboarding, without a business injector
    ///
    /// Used by ``RootCoordinator`` for links that arrive while the launch sequence runs, so before
    /// the initialization of remote secret and the business injector.
    /// - Parameter url: URL to handle
    static func handleLicense(from url: URL) {
        guard url.host()?.lowercased() == "license" else {
            DDLogError(
                "[URLHandler] Failed to handle URL: Not a license URL (\(url.host() ?? "unknown")). Aborting license handling."
            )
            return
        }
        handleLicense(licenseStore: LicenseStore.shared(), query: url.getQueries)
    }
    
    // MARK: Private functions

    private lazy var otherThreemaAppsInstalled: [String: String] = {
        var installedAppsList = [String: String]()
        let current = TargetManager.current
        
        guard current != .customOnPrem else {
            return installedAppsList
        }
        
        if current == .work || current == .onPrem,
           let url = AppURLScheme.threema.url(),
           UIApplication.shared.canOpenURL(url) {
            installedAppsList[AppURLScheme.threema.rawValue] = url.absoluteString
        }
        if current == .threema || current == .onPrem,
           let url = AppURLScheme.threemaWork.url(),
           UIApplication.shared.canOpenURL(url) {
            installedAppsList[AppURLScheme.threemaWork.rawValue] = url.absoluteString
        }
        if current == .threema || current == .work,
           let url = AppURLScheme.threemaOnPrem.url(),
           UIApplication.shared.canOpenURL(url) {
            installedAppsList[AppURLScheme.threemaOnPrem.rawValue] = url.absoluteString
        }
        if current == .green,
           let url = AppURLScheme.threemaBlue.url(),
           UIApplication.shared.canOpenURL(url) {
            installedAppsList[AppURLScheme.threemaBlue.rawValue] = url.absoluteString
        }
        if current == .blue,
           let url = AppURLScheme.threemaGreen.url(),
           UIApplication.shared.canOpenURL(url) {
            installedAppsList[AppURLScheme.threemaGreen.rawValue] = url.absoluteString
        }
        
        return installedAppsList
    }()
}

// MARK: - URLHandler.URLHandlerMapping

extension URLHandler {
    /// URLHandlerMapping
    private enum URLHandlerMapping {
        case threemaDotID(url: URL, targetIdentity: ThreemaIdentity?)
        case linkMobileNoCode(code: String)
        case restore(query: String)
        case compose(query: [String: String])
        case addIdentity(targetIdentity: ThreemaIdentity, query: [String: String])
        case license(query: [String: String])
        case file(url: URL)
        case threemaLink(url: URL)
        case unknown
        
        /// Retrieve the URL mapping for the provided URL.
        /// - Parameter url: URL
        /// - Returns: URLHandlerMapping
        static func map(_ url: URL) -> URLHandlerMapping {
            switch url.scheme {
            case TargetManager.appURLScheme:
                mapAppURLSchemeFrom(url)
                
            case "file":
                .file(url: url)
                
            case "http", "https":
                mapLink(url)
                
            default:
                .unknown
            }
        }
        
        /// Map the host of the App URL Scheme
        /// - Parameter url: URL
        /// - Returns: URLHandlerMapping
        private static func mapAppURLSchemeFrom(_ url: URL) -> URLHandlerMapping {
            switch url.host {
            case "link_mobileno":
                guard let query = url.query(percentEncoded: true) else {
                    DDLogError(
                        "[URLHandler] Failed to handle URL: Can't start link mobile number when query is empty. Aborting link mobile number handling."
                    )
                    return .unknown
                }
                return .linkMobileNoCode(code: query.replacingOccurrences(of: "code=", with: ""))
                
            case "restore":
                guard let query = url.query(percentEncoded: true) else {
                    DDLogError(
                        "[URLHandler] Failed to handle URL: Can't start restore when query is empty. Aborting restore identity handling."
                    )
                    return .unknown
                }
                return .restore(query: query)
                
            case "compose":
                let query = url.getQueries
                
                if let identity = query["id"]?.uppercased(),
                   identity.count == ThreemaIdentity.length {
                    return .addIdentity(targetIdentity: ThreemaIdentity(rawValue: identity), query: query)
                }
                
                return .compose(query: query)
                
            case "add":
                let query = url.getQueries
                
                guard let identity = query["id"]?.uppercased(),
                      identity.count == ThreemaIdentity.length else {
                    return .compose(query: query)
                }
                
                return .addIdentity(targetIdentity: ThreemaIdentity(rawValue: identity), query: query)
                
            case "license":
                let query = url.getQueries
                return .license(query: query)
                
            case .none:
                return .unknown
                
            case .some:
                return .unknown
            }
        }
        
        /// Map the host of the HTTP URL
        /// - Parameter url: URL
        /// - Returns: URLHandlerMapping
        private static func mapLink(_ url: URL) -> URLHandlerMapping {
            switch url.host()?.lowercased() {
            case "threema.id":
                if url.lastPathComponent.count == ThreemaIdentity.length {
                    .threemaDotID(url: url, targetIdentity: ThreemaIdentity(rawValue: url.lastPathComponent))
                }
                else {
                    mapComposeActionsFrom(url)
                }
                
            case "threema.ch", "threema.com":
                .threemaLink(url: url)
                
            default:
                .unknown
            }
        }
        
        private static func mapComposeActionsFrom(_ url: URL) -> URLHandlerMapping {
            guard url.lastPathComponent.lowercased() == "compose" else {
                return .unknown
            }

            let query = url.getQueries

            // Route through `.threemaDotID` so compose links present the same "Open in …" app
            // chooser as `threema.id/<IDENTITY>` links. `handleThreemaDotIDURL` falls back to a plain
            // compose when there is no target identity.
            guard
                let identity = query["id"]?.uppercased(),
                identity.count == ThreemaIdentity.length
            else {
                return .threemaDotID(url: url, targetIdentity: nil)
            }

            return .threemaDotID(url: url, targetIdentity: ThreemaIdentity(rawValue: identity))
        }
    }
}

// MARK: Handle Private Functions

extension URLHandler {
    /// Open the ShareController with the provided text or image.
    /// - Parameter query: The query containing the text and image if provided.
    private func handleCompose(query: [String: String]?) {
        DDLogVerbose("[URLHandler] Handle compose")
        
        // Share with unspecified contact
        Task { @MainActor in
            let shareController = ShareController()
            if let query {
                shareController.text = query["text"]
            }
            shareController.startShare()
        }
    }
    
    /// Present the ID backup restore with the provided backup key.
    /// - Parameter query: The query containing the backup key.
    @MainActor
    private func handleRestore(_ query: String) {
        DDLogVerbose("[URLHandler] Handle restore")
        
        // only react to restore URLs if we're currently presenting the generate key view controller
        guard SharedAppProvider.isPresentingKeyGeneration else {
            DDLogError(
                "[URLHandler] Failed to handle URL: Can't start restore when app is not presenting the setup screen. Aborting restore identity handling."
            )
            return
        }
        
        RestoreDataURLProvider.urlString = query.replacingOccurrences(of: "backup=", with: "")
        SharedAppProvider.presentIDBackupRestore()
    }
    
    /// Function to validate the provided mobile number
    /// - Parameter code: Confirmation code
    private func handleLinkMobileNo(code: String) {
        DDLogVerbose("[URLHandler] Link mobile code: \(code)")
        let connection = ServerAPIConnector()
        
        connection.linkMobileNo(with: MyIdentityStore.shared(), code: code) { _ in
            NotificationPresenterWrapper.shared.present(type: .linkMobileNoSuccess)
        } onError: { _ in
            DDLogError(
                "[URLHandler] Failed to handle URL: Link mobile number failed. Aborting link mobile number handling."
            )
            NotificationPresenterWrapper.shared.present(type: .linkMobileNoFailed)
        }
    }
    
    /// Handle the .threemaID URL
    /// - Parameters:
    ///   - url: URL
    ///   - targetIdentity: Targeted Identity
    ///   - hideAppChooser: Whether to hide the app chooser
    private func handleThreemaDotIDURL(url: URL, targetIdentity: ThreemaIdentity?, hideAppChooser: Bool) {
        DDLogVerbose("[URLHandler] Handle Threema.id URL: \(url)")
        
        guard !TargetManager.isCustomOnPrem else {
            DDLogError(
                "[URLHandler] Failed to handle URL: DotThreemaID is not supported in the current flavor. Aborting DotThreemaID handling."
            )
            return
        }
        
        guard !otherThreemaAppsInstalled.isEmpty, !hideAppChooser else {
            let query = url.getQueries
            
            if let targetIdentity {
                let compose = query["text"] != nil || query["image"] != nil
                addIdentity(targetIdentity, compose: compose, query: query)
            }
            else {
                handleCompose(query: query)
            }
            return
        }
        
        handleAppChooser(url: url, targetIdentity: targetIdentity)
    }
    
    /// Display the application chooser with the installed targets
    /// - Parameters:
    ///   - url: URL
    ///   - targetIdentity: Targeted Identity
    private func handleAppChooser(url: URL, targetIdentity: ThreemaIdentity?) {
        let query = url.getQueries

        Task { @MainActor in
            let alertController = UIAlertController(
                title: #localize("Open in ..."),
                message: url.absoluteString,
                preferredStyle: .alert
            )

            alertController.addAction(UIAlertAction(title: TargetManager.appName, style: .default) { _ in
                self.openURLInCurrentApp(targetIdentity: targetIdentity, query: query)
            })

            for app in otherThreemaAppsInstalled {
                alertController.addAction(UIAlertAction(title: app.key, style: .default) { _ in
                    self.openURLInOtherTargetApp(targetAppURL: app.value, url: url, targetIdentity: targetIdentity)
                })
            }

            URLHandler.topViewController.present(alertController, animated: true)
        }
    }
    
    /// Handle the URL for the current application target
    /// - Parameters:
    ///   - targetIdentity: Targeted Identity
    ///   - query: The query containing the text or image if provided.
    private func openURLInCurrentApp(targetIdentity: ThreemaIdentity?, query: [String: String]) {
        if let targetIdentity {
            addIdentity(
                targetIdentity,
                compose: query["text"] != nil,
                query: query
            )
        }
        else {
            handleCompose(query: query)
        }
    }
    
    /// Construct and open the URL for the other application target
    /// - Parameters:
    ///   - targetAppURL: URL of the other target (e.g. `threema://app`)
    ///   - url: The URL
    ///   - targetIdentity: The Targeted Identity
    private func openURLInOtherTargetApp(targetAppURL: String, url: URL, targetIdentity: ThreemaIdentity?) {
        guard var components = URLComponents(string: targetAppURL) else {
            DDLogError("[URLHandler] Failed to handle URL: \(targetAppURL) is not a valid URL")
            return
        }

        var queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        if let targetIdentity {
            // Without any other parameter the identity is just added, otherwise a message is composed for it
            components.host = queryItems.isEmpty ? "add" : "compose"
            queryItems.insert(URLQueryItem(name: "id", value: targetIdentity.rawValue), at: 0)
        }
        else {
            components.host = "compose"
        }

        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let newURL = components.url else {
            DDLogError("[URLHandler] Failed to handle URL: Unable to compose URL for \(targetAppURL)")
            return
        }

        DDLogVerbose("Open in \(newURL.absoluteString) (\(url.absoluteString))")
        UIApplication.shared.open(newURL)
    }
    
    /// Display the ShareController with the provided URL.
    /// - Parameter url: The URL
    private func handleFile(url: URL) {
        DDLogVerbose("[URLHandler] Handle file: \(url)")
        let shareController = ShareController()
        shareController.url = url
        
        Task { @MainActor [weak shareController] in
            shareController?.startShare()
        }
    }
    
    /// Handle and verify the provided license.
    ///
    /// This is the path of an app that is already set up. While onboarding runs, license links are
    /// handled by ``OnboardingCoordinator``, see ``RootCoordinator.handleLicenseURL(_:)``.
    /// - Parameter licenseStore: Store to handle license in
    /// - Parameter query: Query containing username, password, and server information if provided.
    private static func handleLicense(licenseStore: any LicenseStoreProtocol, query: [String: String]) {
        DDLogVerbose("[URLHandler] Handle license: \(query)")

        guard TargetManager.isBusinessApp else {
            DDLogError("[URLHandler] Failed to handle URL: No license for private app. Aborting license handling.")
            return
        }

        Task { @MainActor in
            guard !licenseStore.isValid() else {
                UIAlertTemplate.showOKAlert(
                    owner: topViewController,
                    title: #localize("already_licensed"),
                    message: nil,
                    actionOk: nil
                )
                DDLogError("[URLHandler] Failed to handle URL: App is already licensed. Aborting license handling.")
                return
            }

            guard let mdmSetup = MDMSetup() else {
                DDLogError("[URLHandler] Failed to handle URL: Missing MDM Setup. Aborting license handling.")
                return
            }

            let applyResult = LicenseCredentials(query: query).apply(
                to: licenseStore,
                mdmSetup: mdmSetup,
                isOnPrem: TargetManager.isOnPrem
            )

            guard applyResult == .complete else {
                NotificationCenter.default.post(
                    name: Notification.Name(rawValue: kNotificationLicenseMissing),
                    object: applyResult == .invalidServer
                        ? #localize("enter_license_invalid_url_link")
                        : nil
                )
                DDLogError(
                    "[URLHandler] Failed to handle URL: License link is \(applyResult). Aborting license handling."
                )
                return
            }

            await performLicenseCheck(with: licenseStore)
        }
    }

    /// Verify the credentials in the license store and, if the license entry screen is presented,
    /// dismiss it and reconnect.
    /// - Parameter licenseStore: LicenseStore
    @MainActor
    private static func performLicenseCheck(with licenseStore: any LicenseStoreProtocol) async {
        guard await licenseStore.performLicenseCheck() else {
            NotificationCenter.default.post(
                name: Notification.Name(rawValue: kNotificationLicenseMissing),
                object: nil
            )
            DDLogError("[URLHandler] Failed to handle URL: License is missing. Aborting perform license check.")
            return
        }

        do {
            try await WorkDataThreemaMDMFetcher(licenseStore: licenseStore).checkUpdateThreemaMDM()
        }
        catch {
            DDLogError("[URLHandler] Failed to handle URL: Threema MDM fetch failed (\(error)).")
            NotificationCenter.default.post(
                name: Notification.Name(rawValue: kNotificationLicenseMissing),
                object: nil
            )
            return
        }

        guard SharedAppProvider.isPresentingEnterLicense else {
            // The app is licensed again and there is no license entry screen to dismiss
            DDLogNotice("[URLHandler] License is valid and license screen is not presented.")
            return
        }

        SharedAppProvider.window?.rootViewController?.dismiss(animated: true) {
            Task { @MainActor in
                // The app coordinator is gone if the app isn't set up (yet); the license
                // credentials are stored, so the next launch connects with them.
                SharedAppProvider.appCoordinator?.setupConnection()
            }
        }
    }
    
    /// Verify the existence of a contact and add the specified identity to the database.
    /// - Parameters:
    ///   - targetIdentity: The targeted identity to be added.
    ///   - compose: Whether to compose a message to this contact.
    ///   - query: The query with the text or image if provided.
    private func addIdentity(_ targetIdentity: ThreemaIdentity, compose: Bool, query: [String: String]) {
        DDLogVerbose("[URLHandler] Add Identity: \(targetIdentity), compose: \(compose), query: \(query)")
        
        guard targetIdentity.rawValue != businessInjector.profileStore.profile.myIdentity.rawValue else {
            DDLogError("[URLHandler] Failed to handle URL: Can't add own identity. Aborting add identity handling.")
            return
        }
        
        // First, let’s check if MDMSetup is available (not for private flavors) and make sure the ‘add contacts’ option
        // is disabled. Then, we’ll double-check that this contact already exists because we can’t add any new ones.
        if let mdmSetup = MDMSetup(),
           mdmSetup.disableAddContact() {
            guard businessInjector.entityManager.entityFetcher.contactEntity(for: targetIdentity.rawValue) != nil else {
                DDLogError(
                    "[URLHandler] Failed to handle URL: Can't add contact because it's disabled. Aborting add identity handling."
                )
                return
            }
        }
        
        businessInjector.contactStore.addContact(
            with: targetIdentity.rawValue,
            verificationLevel: Int32(VerificationLevel.unverified.rawValue),
            onCompletion: { contactEntity, _ in
                if compose,
                   query["text"] != nil || query["image"] != nil {
                    Task { @MainActor in
                        let shareController = ShareController()
                        shareController.contact = contactEntity as? ContactEntity
                        shareController.text = query["text"]
                        shareController.startShare()
                    }
                }
                else {
                    // just show contact details
                    let dict = [kKeyContact: contactEntity as Any, "fromURL": true]
                    Task {
                        NotificationCenter.default.post(
                            name: Notification.Name(kNotificationShowContact),
                            object: nil,
                            userInfo: dict
                        )
                    }
                }
            }, onError: { _ in
                NotificationPresenterWrapper.shared.present(type: .addContactFailed)
                DDLogError("[URLHandler] Failed to handle URL: Add contact failed. Aborting add identity handling.")
            }
        )
    }
}

// MARK: ShortcutItems

extension URLHandler {
    @MainActor
    func handle(item: UIApplicationShortcutItem) -> Bool {
        if item.type == "ch.threema.newmessage" {
            handleCompose(query: nil)
            return true
        }
        else if item.type == "ch.threema.myid" {
            guard let tabBar = SharedAppProvider.tabBarController else {
                return false
            }
            tabBar.selectedIndex = Int(kMyIdentityTabBarIndex)
            return true
        }
        else if item.type == "ch.threema.scanid" {
            guard let tabBar = SharedAppProvider.tabBarController else {
                return false
            }
            if !DeviceCapabilitiesManager().hasVideoCaptureDevice {
                DDLogVerbose("No Camera available.")
                return false
            }
            if TargetManager.isBusinessApp, MDMSetup()?.disableAddContact() == true {
                DDLogVerbose("Contact scanning is disabled for this business app.")
                return false
            }
            
            let model = QRCodeScannerViewModel(
                mode: .identity,
                audioSessionManager: BusinessInjector.ui.audioSessionManager,
                systemFeedbackManager: SystemFeedbackManager(
                    deviceCapabilitiesManager: DeviceCapabilitiesManager(),
                    settingsStore: BusinessInjector.ui.settingsStore
                ),
                systemPermissionsManager: SystemPermissionsManager()
            )
            model.onCompletion = { result in
                self.handleScannerResult(result)
            }
            model.onCancel = {
                tabBar.dismiss(animated: true)
            }
            let rootView = QRCodeScannerView(model: model)
            let viewController = UIHostingController(rootView: rootView)
            let nav = PortraitNavigationController(rootViewController: viewController)
            URLHandler.topViewController.present(nav, animated: true)
            
            return true
        }
        else {
            DDLogError("[URLHandler] Unknown shortcut type: (\(item.type)). Aborting shortcut handling.")
            return false
        }
    }
}

// MARK: ScannerResult

extension URLHandler {
    private func handleScannerResult(_ result: QRCodeScannerViewModel.QRCodeResult) {
        MainActor.assumeIsolated {
            switch result {
            case let .identityContact(identity: id, publicKey: key, expirationDate: date):
                let model = ContactIdentityProcessingViewModel(
                    expectedIdentity: nil,
                    scannedIdentity: id,
                    scannedPublicKey: key,
                    scannedExpirationDate: date,
                    systemFeedbackManager: SystemFeedbackManager(
                        deviceCapabilitiesManager: DeviceCapabilitiesManager(),
                        settingsStore: BusinessInjector.ui.settingsStore
                    )
                )
                model.onCompletion = { verifiedContact in
                    URLHandler.topViewController.dismiss(animated: true) {
                        if let verifiedContact {
                            let name = Notification.Name(kNotificationShowContact)
                            let userInfo = [kKeyContact: verifiedContact]
                            NotificationCenter.default.post(name: name, object: nil, userInfo: userInfo)
                        }
                    }
                }
                let rootView = ContactIdentityProcessingView(model: model)
                let viewController = UIHostingController(rootView: rootView)
                (URLHandler.topViewController as? UINavigationController)?.pushViewController(
                    viewController,
                    animated: true
                )
                
            case let .identityLink(url: url):
                URLHandler.topViewController.dismiss(animated: true) {
                    self.handle(url, hideAppChooser: true)
                }
                
            default:
                break
            }
        }
    }
}

// MARK: Helper functions

extension URLHandler {
    private enum AppURLScheme: String {
        case threema = "Threema"
        case threemaWork = "Threema Work"
        case threemaOnPrem = "Threema OnPrem"
        case threemaBlue = "Threema Blue"
        case threemaGreen = "Threema Green"
        
        func url() -> URL? {
            switch self {
            case .threema:
                URL(string: "threema://app")
            case .threemaWork:
                URL(string: "threemawork://app")
            case .threemaOnPrem:
                URL(string: "threemaonprem://app")
            case .threemaBlue:
                URL(string: "threemablue://app")
            case .threemaGreen:
                URL(string: "threemagreen://app")
            }
        }
    }
    
    @MainActor
    private static var topViewController: UIViewController {
        SharedAppProvider.currentTopViewController ?? UIViewController()
    }
}
