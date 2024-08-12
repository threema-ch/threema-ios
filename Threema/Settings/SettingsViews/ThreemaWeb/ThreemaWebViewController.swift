//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2024 Threema GmbH
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
import PromiseKit
import SwiftUI
import ThreemaFramework
import UIKit

class ThreemaWebViewController: ThemedTableViewController {
    
    @IBOutlet var cameraButton: UIBarButtonItem!
    
    var entityManager = EntityManager()
    var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>?
    var selectedIndexPath: IndexPath?
    
    // This should always be in sync with `disableMultiDeviceForVersionLessThan5()`
    private lazy var sections: [Section] = Section.allCases

    private var rendezvousServerAvailable = false
    
    fileprivate enum Section: CaseIterable {
        case web
        case webSessions
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Hide MD information if is rendezvous server missing (means MD config is missing in general)
        let factory = ServerInfoProviderFactory.makeServerInfoProvider()
        factory.rendezvousServer { rendezvousServerInfo, _ in
            self.rendezvousServerAvailable = rendezvousServerInfo != nil
            
            if self.rendezvousServerAvailable, !UserSettings.shared().desktopInfoBannerShown {
                Task { @MainActor in
                    self.addHeaderView()
                }
            }
        }

        fetchedResultsController = entityManager.entityFetcher.fetchedResultsControllerForWebClientSessions()
        fetchedResultsController!.delegate = self
        
        do {
            try fetchedResultsController!.performFetch()
        }
        catch {
            ErrorHandler.abortWithError(nil)
        }
        
        title = BundleUtil.localizedString(forKey: "webClientSession_title")
        
        ServerInfoProviderFactory.makeServerInfoProvider()
            .webServer(ipv6: UserSettings.shared().enableIPv6) { webServerInfo, _ in
                if let webServerURL = webServerInfo?.url {
                    ThreemaWebQRCodeScanner.shared.threemaWebServerURL = webServerURL
                }
                if let overrideSaltyRtcHost = webServerInfo?.overrideSaltyRtcHost {
                    ThreemaWebQRCodeScanner.shared.overrideSaltyRtcHost = overrideSaltyRtcHost
                }
                if let overrideSaltyRtcPort = webServerInfo?.overrideSaltyRtcPort {
                    ThreemaWebQRCodeScanner.shared.overrideSaltyRtcPort = overrideSaltyRtcPort
                }
            }
    }
    
    private lazy var headerView: UIView =
        UIHostingController(rootView: ThreemaWebDesktopInfoBannerView(onTap: {
            self.showDesktopSettings()
        }, dismissAction: {
            self.removeHeaderView()
        })).view
   
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let mdmSetup = MDMSetup(setup: false)!
        cameraButton.isEnabled = !mdmSetup.disableWeb()
        
        cleanupWebClientSessions()
        
        cameraButton.image = UIImage(systemName: "qrcode.viewfinder")!.withTint(.primary)
        cameraButton.accessibilityLabel = BundleUtil.localizedString(forKey: "scan_qr")
        
        ThreemaWebQRCodeScanner.shared.delegate = self
        
        tableView.reloadData()
    }
    
    // MARK: - Private functions
    
    private func addHeaderView() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        
        tableView.beginUpdates()

        tableView.tableHeaderView = headerView
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: tableView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: tableView.frameLayoutGuide.leadingAnchor),
            headerView.bottomAnchor.constraint(equalTo: tableView.bottomAnchor),
            headerView.trailingAnchor.constraint(equalTo: tableView.frameLayoutGuide.trailingAnchor),
        ])
        
        tableView.setNeedsLayout()
        tableView.layoutIfNeeded()
        tableView.endUpdates()
    }
    
    private func removeHeaderView() {
        UserSettings.shared().desktopInfoBannerShown = true
        
        tableView.beginUpdates()
        headerView.removeFromSuperview()
        tableView.tableHeaderView = nil
        tableView.setNeedsLayout()
        tableView.layoutIfNeeded()
        tableView.endUpdates()
    }
    
    private func showDesktopSettings() {
        dismiss(animated: true) {
            NotificationCenter.default.post(name: .showDesktopSettings, object: nil)
        }
    }
    
    private func presentActionSheetForSession(_ webClientSession: WebClientSession, indexPath: IndexPath) {
        let alert = UIAlertController(
            title: BundleUtil.localizedString(forKey: "webClientSession_actionSheetTitle"),
            message: nil,
            preferredStyle: .actionSheet
        )
        
        if (webClientSession.active?.boolValue)! {
            // Stop action
            alert
                .addAction(UIAlertAction(
                    title: BundleUtil
                        .localizedString(forKey: "webClientSession_actionSheet_stopSession"),
                    style: .default
                ) { _ in
                    ValidationLogger.shared().logString("[Threema Web] Disconnect webclient userStoppedSession")
                    WCSessionManager.shared.stopSession(webClientSession)
                })
        }
        else {
            // Start action
            alert
                .addAction(UIAlertAction(
                    title:
                    BundleUtil
                        .localizedString(forKey: "webClientSession_actionSheet_startSession"),
                    style: .default
                ) { _ in
                    ValidationLogger.shared().logString("[Threema Web] User start connection")
                    WCSessionManager.shared.connect(authToken: nil, wca: nil, webClientSession: webClientSession)
                })
        }
        
        // Rename action
        alert
            .addAction(
                UIAlertAction(
                    title: BundleUtil.localizedString(forKey: "webClientSession_actionSheet_renameSession"),
                    style: .default
                ) { _ in
                    
                    let renameAlert = UIAlertController(
                        title: BundleUtil.localizedString(forKey: "webClientSession_sessionName"),
                        message: nil,
                        preferredStyle: .alert
                    )
                    
                    renameAlert.addTextField { textfield in
                        if let sessionName = webClientSession.name {
                            textfield.text = sessionName
                        }
                        else {
                            textfield.placeholder = BundleUtil.localizedString(forKey: "webClientSession_unnamed")
                        }
                    }
                    
                    let saveAction = UIAlertAction(
                        title: BundleUtil.localizedString(forKey: "save"),
                        style: .default
                    ) { _ in
                        let textField = renameAlert.textFields![0]
                        WebClientSessionStore.shared.updateWebClientSession(
                            session: webClientSession,
                            sessionName: textField.text
                        )
                        self.tableView.deselectRow(at: indexPath, animated: true)
                    }
                    renameAlert.addAction(saveAction)
                    
                    let cancelAction = UIAlertAction(
                        title: BundleUtil.localizedString(forKey: "cancel"),
                        style: .cancel
                    ) { _ in
                        self.tableView.deselectRow(at: indexPath, animated: true)
                    }
                    renameAlert.addAction(cancelAction)
                    
                    self.present(renameAlert, animated: true)
                }
            )
        
        // Delete action
        alert.addAction(UIAlertAction(
            title: BundleUtil.localizedString(forKey: "webClientSession_actionSheet_deleteSession"),
            style: .destructive
        ) { _ in
            self.deleteWebClientSession(webClientSession)
        })
        
        // Cancel action
        alert.addAction(UIAlertAction(title: BundleUtil.localizedString(forKey: "cancel"), style: .cancel) { _ in
            self.tableView.deselectRow(at: indexPath, animated: true)
        })
        
        if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad {
            alert.popoverPresentationController?.sourceRect = tableView.rectForRow(at: indexPath)
            alert.popoverPresentationController?.sourceView = tableView
        }
        
        present(alert, animated: true)
    }
    
    /// Will delete all not persistent sessions where are older then 24 hours and not active
    private func cleanupWebClientSessions() {
        guard let allSessions = entityManager.entityFetcher.allWebClientSessions() as? [WebClientSession] else {
            return
        }
        
        for session in allSessions {
            if session.permanent?.boolValue == true {
                continue
            }
            
            if let date = session.lastConnection {
                if let diff = Calendar.current.dateComponents([.hour], from: date, to: Date()).hour, diff > 24 {
                    if session.active?.boolValue == false {
                        WebClientSessionStore.shared.deleteWebClientSession(session)
                    }
                }
            }
        }
    }
    
    private func deleteWebClientSession(_ session: WebClientSession) {
        WCSessionManager.shared.stopAndDeleteSession(session)
        
        if fetchedResultsController!.fetchedObjects!.isEmpty {
            UserSettings.shared().threemaWeb = false
        }
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        fetchedResultsController!.sections!.count + (sections.count - 1)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .web:
            1
        case .webSessions:
            fetchedResultsController!.fetchedObjects!.count
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch sections[section] {
        case .webSessions:
            if !(fetchedResultsController?.fetchedObjects?.isEmpty ?? true) {
                BundleUtil.localizedString(forKey: "webClientSession_sessions_header")
            }
            else {
                nil
            }
        default:
            nil
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch sections[section] {
        case .web:
            let mdmSetup = MDMSetup(setup: false)!
            if mdmSetup.existsMdmKey(MDM_KEY_DISABLE_WEB) {
                return BundleUtil.localizedString(forKey: "disabled_by_device_policy")
            }
            else {
                return String.localizedStringWithFormat(
                    BundleUtil.localizedString(forKey: "settings_threema_web_connectioninfo"),
                    ThreemaApp.currentName,
                    ThreemaApp.currentName
                )
            }
        case .webSessions:
            return String.localizedStringWithFormat(
                BundleUtil.localizedString(forKey: "webClientSession_add_footer"),
                ThreemaWebQRCodeScanner.shared.downloadString,
                ThreemaWebQRCodeScanner.shared.threemaWebServerURL
            )
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .web:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: "ThreemaWebSettingCell",
                for: indexPath
            ) as! ThreemaWebSettingCell
            cell.setupCell()
            return cell
            
        default:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: "WebClientSessionCell",
                for: indexPath
            ) as! WebClientSessionCell
            cell.webClientSession = fetchedResultsController!.fetchedObjects![indexPath.row] as? WebClientSession
            cell.viewController = self
            cell.setupCell()
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if sections[indexPath.section] == .web, indexPath.row == 0 {
            return nil
        }
        return indexPath
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch sections[indexPath.section] {
        case .web:
            break // Do nothing
            
        case .webSessions:
            let webClientSession = fetchedResultsController!.fetchedObjects![indexPath.row] as! WebClientSession
            presentActionSheetForSession(webClientSession, indexPath: indexPath)
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        sections[indexPath.section] == .webSessions
    }
    
    override func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        if editingStyle == .delete {
            let webClientSession = fetchedResultsController!.fetchedObjects![indexPath.row] as! WebClientSession
            deleteWebClientSession(webClientSession)
        }
    }
}

extension ThreemaWebViewController {
    @IBAction func threemaWebSwitchChanged(_ sender: Any) {
        let threemaWebSwitch = sender as! UISwitch
        UserSettings.shared().threemaWeb = threemaWebSwitch.isOn
        
        if !threemaWebSwitch.isOn {
            // disconnect if there is a active session
            ValidationLogger.shared()?.logString("[Threema Web] Disconnect webclient threemaWebOff")
            WCSessionManager.shared.stopAllSessions()
            
            // delete all not saved sessions if it's off
            WCSessionManager.shared.removeAllNotPermanentSessions()
        }
        else {
            if fetchedResultsController!.fetchedObjects!.isEmpty {
                ThreemaWebQRCodeScanner.shared.scan()
            }
        }
    }
}

// MARK: - ThreemaWebQRCodeScannerDelegate

extension ThreemaWebViewController: ThreemaWebQRCodeScannerDelegate {
    func showAlert(result: String?) {
        DDLogWarn("[Threema Web] Can't read QR-Code")
        
        let title: String
        let message: String
        
        if rendezvousServerAvailable,
           let result,
           let resultURL = URL(string: result),
           let parsedURL = try? URLParser.parse(url: resultURL),
           case .deviceGroupJoinRequestOffer = parsedURL {
            title = BundleUtil.localizedString(forKey: "settings_threema_web_multi_device_qr_code_title")
            message = String.localizedStringWithFormat(
                BundleUtil.localizedString(forKey: "settings_threema_web_multi_device_qr_code_message"),
                BundleUtil.localizedString(forKey: "settings"),
                BundleUtil.localizedString(forKey: "settings_list_threema_desktop_title")
            )
        }
        else {
            title = BundleUtil.localizedString(forKey: "webClientSession_add_wrong_qr_title")
            message = String.localizedStringWithFormat(
                BundleUtil.localizedString(forKey: "webClientSession_add_wrong_qr_message"),
                ThreemaWebQRCodeScanner.shared.downloadString,
                ThreemaWebQRCodeScanner.shared.threemaWebServerURL
            )
        }
        
        if let vc = AppDelegate.shared().currentTopViewController() {
            vc.dismiss(animated: true) {
                UIAlertTemplate.showAlert(owner: self, title: title, message: message)
            }
        }
    }
}

// MARK: - ThreemaWebQRCodeScannerDelegate

protocol ThreemaWebQRCodeScannerDelegate: AnyObject {
    func showAlert(result: String?)
}

// MARK: - ThreemaWebQRCodeScanner

class ThreemaWebQRCodeScanner: QRScannerViewControllerDelegate {
    static let shared = ThreemaWebQRCodeScanner()
    
    fileprivate weak var delegate: ThreemaWebQRCodeScannerDelegate?
    
    fileprivate var overrideSaltyRtcPort: Int?
    fileprivate var overrideSaltyRtcHost: String?
    
    fileprivate var threemaWebServerURL: String = BundleUtil.object(forInfoDictionaryKey: "ThreemaWebURL") as! String
    fileprivate var downloadString: String {
        switch ThreemaApp.current {
        case .work, .blue, .onPrem:
            "https://threema.ch/work/download"
        default:
            "https://threema.ch/download"
        }
    }
    
    func scan() {
        let nav = PortraitNavigationController(
            rootViewController: QRScannerViewController().then {
                $0.delegate = self
                $0.title = BundleUtil.localizedString(forKey: "scan_qr")
                $0.navigationItem.scrollEdgeAppearance = Colors.defaultNavigationBarAppearance()
            }
        )
        nav.modalTransitionStyle = .crossDissolve
        AppDelegate.shared().currentTopViewController().present(nav, animated: true)
    }
    
    func qrScannerViewController(_ controller: QRScannerViewController, didScanResult result: String?) {
        if UserSettings.shared().inAppVibrate {
            AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
        }
  
        guard let result, let qrCodeData = Data(base64Encoded: result) else {
            delegate?.showAlert(result: result)
            
            return
        }
        
        if !UserSettings.shared().threemaWeb {
            UserSettings.shared().threemaWeb = true
        }
        
        func scannedCodeHandler() {
            handleScannedCode(data: qrCodeData) { error in
                if error == false {
                    AppDelegate.shared().currentTopViewController().map {
                        $0.dismiss(animated: true, completion: nil)
                    }
                }
                else {
                    controller.stopRunning()
                }
            }
        }

        // Don't enable Threema Web until all contacts have a non-nil feature mask
        if let identities = ContactStore.shared().contactsWithFeatureMaskNil(), !identities.isEmpty {
            ContactStore.shared().updateFeatureMasks(forIdentities: identities) {
                scannedCodeHandler()
            } onError: { error in
                DDLogError("Update feature mask failed: \(error)")
                scannedCodeHandler()
            }
        }
        else {
            scannedCodeHandler()
        }
    }
    
    func qrScannerViewController(
        _ controller: QRScannerViewController,
        didCancelAndWillDismissItself willDismissItself: Bool
    ) {
        if !willDismissItself {
            AppDelegate.shared().currentTopViewController().map {
                $0.dismiss(animated: true)
            }
        }
    }
    
    private func handleScannedCode(data: Data, completion: @escaping (_ error: Bool?) -> Void) {
        do {
            let format = String(format: ">HB32B32B32BH%is", (data.count) - 101)
            let a = try unpack(format, data)
            
            let allOptions = Bitfield(rawValue: a[1] as! Int)
            var initiatorPermanentPublicKeyArray = [UInt8]()
            for index in 2...33 {
                initiatorPermanentPublicKeyArray.append(UInt8(a[index] as! Int))
            }
            var authTokenArray = [UInt8]()
            for index in 34...65 {
                authTokenArray.append(UInt8(a[index] as! Int))
            }
            var serverPermanentPublicKeyArray = [UInt8]()
            for index in 66...97 {
                serverPermanentPublicKeyArray.append(UInt8(a[index] as! Int))
            }
            
            let scanController = ScanIdentityController()
            scanController.playSuccessSound()
            
            var session = [String: Any]()
            session.updateValue(a[0] as! Int, forKey: "webClientVersion")
            session.updateValue(allOptions.contains(.permanent) ? true : false, forKey: "permanent")
            session.updateValue(allOptions.contains(.selfHosted) ? true : false, forKey: "selfHosted")
            session.updateValue(Data(initiatorPermanentPublicKeyArray), forKey: "initiatorPermanentPublicKey")
            session.updateValue(Data(serverPermanentPublicKeyArray), forKey: "serverPermanentPublicKey")
            session.updateValue(a[98] as! Int, forKey: "saltyRTCPort")
            session.updateValue(a[99] as! NSString, forKey: "saltyRTCHost")
            
            if let overrideSaltyRtcHost {
                DDLogNotice(
                    "[Threema Web] override SaltyRtcHost from \(session["saltyRTCHost"] ?? "?") to \(overrideSaltyRtcHost)"
                )
                session.updateValue(overrideSaltyRtcHost, forKey: "saltyRTCHost")
            }
            if let overrideSaltyRtcPort {
                DDLogNotice(
                    "[Threema Web] override SaltyRtcPort from \(session["saltyRTCPort"] ?? "?") to \(overrideSaltyRtcPort)"
                )
                session.updateValue(overrideSaltyRtcPort, forKey: "saltyRTCPort")
            }
            
            if LicenseStore.requiresLicenseKey() == true {
                let mdmSetup = MDMSetup(setup: false)!
                if let webHosts = mdmSetup.webHosts() {
                    if WCSessionManager.isWebHostAllowed(
                        scannedHostName: session["saltyRTCHost"] as! String,
                        whiteList: webHosts
                    ) == false {
                        ValidationLogger.shared().logString("[Threema Web] Scanned qr code host is not white listed")
                        let topViewController = AppDelegate.shared()?.currentTopViewController()
                        UIAlertTemplate.showAlert(
                            owner: topViewController!,
                            title: BundleUtil.localizedString(forKey: "webClient_scan_error_mdm_host_title"),
                            message: BundleUtil.localizedString(forKey: "webClient_scan_error_mdm_host_message")
                        ) { _ in
                            AppDelegate.shared().currentTopViewController().map {
                                $0.dismiss(animated: true, completion: nil)
                            }
                        }
                        completion(true)
                        return
                    }
                }
            }
            
            ValidationLogger.shared().logString("[Threema Web] Scanned qr code")
            
            let webClientSession = WebClientSessionStore.shared.addWebClientSession(dictionary: session)
            
            WCSessionManager.shared.connect(
                authToken: Data(authTokenArray),
                wca: nil,
                webClientSession: webClientSession
            )
            completion(false)
        }
        catch {
            ValidationLogger.shared().logString("[Threema Web] Can't read qr code")
            completion(false)
        }
    }
}

struct Bitfield: OptionSet {
    let rawValue: Int
    
    static let selfHosted = Bitfield(rawValue: 1 << 0)
    static let permanent = Bitfield(rawValue: 1 << 1)
}

// MARK: - ThreemaWebViewController + NSFetchedResultsControllerDelegate

extension ThreemaWebViewController: NSFetchedResultsControllerDelegate {
    
    public func controller(
        _ controller: NSFetchedResultsController<NSFetchRequestResult>,
        didChange anObject: Any,
        at indexPath: IndexPath?,
        for type: NSFetchedResultsChangeType,
        newIndexPath: IndexPath?
    ) {
        tableView.reloadData()
    }

    @nonobjc public func controller(
        _ controller: NSFetchedResultsController<NSFetchRequestResult>,
        didChange sectionInfo: NSFetchedResultsSectionInfo,
        atSectionIndex sectionIndex: Int,
        for type: NSFetchedResultsChangeType
    ) {
        tableView.reloadData()
    }
        
    public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.reloadData()
    }
}

// MARK: - UIViewControllerRepresentable

struct ThreemaWebViewControllerRepresentable: UIViewControllerRepresentable {
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) { }
    
    func makeUIViewController(context: Context) -> some UIViewController {
        let storyboard = UIStoryboard(name: "SettingsStoryboard", bundle: nil)
        return storyboard.instantiateViewController(identifier: "ThreemaWeb") as ThreemaWebViewController
    }
}
