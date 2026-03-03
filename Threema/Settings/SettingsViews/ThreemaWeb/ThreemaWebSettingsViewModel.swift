//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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
import Combine
import CoreData
import SwiftUI
import ThreemaEssentials
import ThreemaFramework
import ThreemaMacros

@MainActor
final class ThreemaWebSettingsViewModel: NSObject, ObservableObject {
    
    // MARK: State

    @Published var isWebEnabled = false
    @Published var canScan = true
    @Published var showDesktopInfoBanner = false
    @Published var rendezvousAvailable = false
    @Published var sessions: [WebClientSessionEntity] = []

    @Published var selectedSession: WebClientSessionEntity?
    @Published var showSessionActions = false
    @Published var showRenamePrompt = false
    @Published var renameText = ""

    @Published var alertTitle: String?
    @Published var alertMessage: String?
    @Published var showAlert = false

    let addSessionHeaderLabel = #localize("webClientSession_sessions_header")
    let alertDialogTitle = #localize("webClientSession_sessionName")
    let cancelButtonTitle = #localize("cancel")
    let confirmationDialogTitle = #localize("webClientSession_actionSheetTitle")
    let defaultSessionName = #localize("webClientSession_unnamed")
    let deleteButtonTitle = #localize("webClientSession_actionSheet_deleteSession")
    let okButtonTitle = #localize("ok")
    let renameButtonTitle = #localize("webClientSession_actionSheet_renameSession")
    let saveButtonTitle = #localize("save")
    let scanButtonIconName = "qrcode.viewfinder"
    let screenTitle = #localize("settings_list_threema_web_title")
    let sessionTitle = #localize("webClientSession_title")

    lazy var addSessionFooterLabel = String.localizedStringWithFormat(
        #localize("webClientSession_add_footer"), downloadString, threemaWebServerURL
    )

    var sessionToggleButtonTitle: String? {
        if isSessionActive {
            #localize("webClientSession_actionSheet_stopSession")
        }
        else {
            #localize("webClientSession_actionSheet_startSession")
        }
    }

    var webToggleFooterLabel: String {
        if mdmKeyExists {
            return #localize("disabled_by_device_policy")
        }
        else {
            let appName = TargetManager.appName
            return String.localizedStringWithFormat(#localize("settings_threema_web_connectioninfo"), appName, appName)
        }
    }

    // MARK: Private

    private let qrCodeParser = QRCodeParser()
    private var overrideSaltyRtcPort: Int?
    private var overrideSaltyRtcHost: String?
    private var threemaWebServerURL: String = BundleUtil.object(forInfoDictionaryKey: "ThreemaWebURL") as? String ?? ""

    private lazy var entityManager = BusinessInjector.ui.entityManager
    private lazy var serverInfoProvider = ServerInfoProviderFactory.makeServerInfoProvider()
    private lazy var sessionManager = WCSessionManager.shared
    private lazy var userSettings = UserSettings.shared()!
    private lazy var webClientSessionStore = WebClientSessionStore.shared
    private lazy var contactStore = ContactStore.shared()
    private lazy var appDelegate = AppDelegate.shared()

    private var downloadString: String {
        if TargetManager.isBusinessApp {
            ThreemaURLProvider.workDownload.absoluteString
        }
        else {
            ThreemaURLProvider.consumerDownload.absoluteString
        }
    }

    private lazy var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult> = {
        let controller = entityManager.entityFetcher.fetchedResultsControllerForWebClientSessionEntities()
        controller.delegate = self
        return controller
    }()

    private lazy var systemFeedbackManager = SystemFeedbackManager(
        deviceCapabilitiesManager: DeviceCapabilitiesManager(),
        settingsStore: BusinessInjector.ui.settingsStore
    )

    private var isSessionActive: Bool {
        selectedSession?.active?.boolValue == true
    }

    private var mdmKeyExists: Bool {
        MDMSetup()?.existsMdmKey(MDM_KEY_DISABLE_WEB) == true
    }

    private var mdmWebDisabled: Bool {
        MDMSetup()?.disableWeb() ?? false
    }

    private var topViewController: UIViewController {
        appDelegate?.currentTopViewController() ?? UIViewController()
    }

    // MARK: Lifecycle
    
    override init() {
        super.init()
        self.isWebEnabled = userSettings.threemaWeb

        serverInfoProvider.rendezvousServer { [weak self] info, _ in
            Task { @MainActor [weak self] in
                guard let self, let mdm = MDMSetup() else {
                    return
                }
                
                self.rendezvousAvailable = (info != nil)
                
                let infoBannerShown = userSettings.desktopInfoBannerShown

                if rendezvousAvailable, !mdm.disableMultiDevice(), !infoBannerShown {
                    self.showDesktopInfoBanner = true
                }
            }
        }

        let enableIPv6 = userSettings.enableIPv6
        serverInfoProvider.webServer(ipv6: enableIPv6) { info, _ in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                if let url = info?.url {
                    self.threemaWebServerURL = url
                }
                if let host = info?.overrideSaltyRtcHost {
                    self.overrideSaltyRtcHost = host
                }
                if let port = info?.overrideSaltyRtcPort {
                    self.overrideSaltyRtcPort = port
                }
            }
        }

        addObservers()
    }

    // MARK: - Public actions
    
    func load() {
        canScan = !mdmWebDisabled && DeviceCapabilitiesManager().supportsRecordingVideo
        reloadSessions()
        cleanupOldNonPermanentSessions()
    }

    func toggleWeb(_ newValue: Bool) {
        isWebEnabled = newValue
        threemaWebSwitchChanged()
    }

    func scan() {
        guard canScan else {
            return
        }
        showScanner()
    }

    func presentActions(for session: WebClientSessionEntity) {
        selectedSession = session
        showSessionActions = true
    }

    func deleteSessions(at indexSet: IndexSet) {
        indexSet
            .compactMap { $0 < sessions.count ? sessions[$0] : nil }
            .forEach {
                sessionManager.stopAndDeleteSession($0)
            }
        updateThreemaWebSetting()
    }

    func startOrStopSelectedSession() {
        guard let s = selectedSession else {
            return
        }
        if s.active?.boolValue ?? false {
            sessionManager.stopSession(s)
        }
        else {
            sessionManager.connect(authToken: nil, wca: nil, webClientSession: s)
        }
    }

    func askRename() {
        guard let session = selectedSession else {
            return
        }
        renameText = session.name ?? ""
        showRenamePrompt = true
    }

    func confirmRename() {
        guard let session = selectedSession else {
            return
        }
        webClientSessionStore.updateWebClientSession(session: session, sessionName: renameText)
    }

    func deleteSelected() {
        guard let session = selectedSession else {
            return
        }
        deleteSession(session)
    }

    func dismissBanner() {
        userSettings.desktopInfoBannerShown = true
        showDesktopInfoBanner = false
    }

    // MARK: - Private Types

    private enum QRCodeScanResult {
        case webSessionData(session: [String: Any], authToken: Data)
        case webSessionNotAllowedForBusinessApp
        case invalidData
    }

    // MARK: - Helpers

    private func addObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(mdmChanged),
            name: Notification.Name(kNotificationSettingStoreSynchronization),
            object: nil
        )
    }

    @objc private func mdmChanged() {
        if mdmWebDisabled {
            isWebEnabled = false
            threemaWebSwitchChanged()
        }
    }

    private func showScanner() {
        let model = QRCodeScannerViewModel(
            mode: .webSession,
            audioSessionManager: AudioSessionManager(),
            systemFeedbackManager: SystemFeedbackManager(
                deviceCapabilitiesManager: DeviceCapabilitiesManager(),
                settingsStore: BusinessInjector.ui.settingsStore
            ),
            systemPermissionsManager: SystemPermissionsManager()
        )
        let rootView = QRCodeScannerView(model: model)
        let viewController = UIHostingController(rootView: rootView)
        let nav = PortraitNavigationController(rootViewController: viewController)

        topViewController.present(nav, animated: true)
        model.onCompletion = { [weak self] result in
            guard let self, case let .webSession(session: session, authToken) = result else {
                return
            }
            topViewController.dismiss(animated: true) { [weak self] in
                self?.processScanResult(session: session, authToken: authToken)
            }
        }
        model.onCancel = { [weak self] in
            self?.topViewController.dismiss(animated: true) { [weak self] in
                self?.updateThreemaWebSetting()
            }
        }
        model.onDisappear = { [weak self] in
            self?.updateThreemaWebSetting()
        }
    }

    private func processScanResult(session: [String: Any], authToken: Data) {
        let session = overrideSession(session)

        if isWebHostDisallowedForBusinessApp(session) {
            showAlertForUnauthorizedSession()
        }
        else {
            Task {
                systemFeedbackManager.playSuccessSound()
                await updateContactsFeatureMask()
                userSettings.threemaWeb = true
                isWebEnabled = true
                connectToWebSession(session: session, authToken: authToken)
            }
        }
    }

    private func overrideSession(_ session: [String: Any]) -> [String: Any] {
        var session = session
        if let overrideSaltyRtcHost {
            session.updateValue(overrideSaltyRtcHost, forKey: "saltyRtcHost")
        }
        if let overrideSaltyRtcPort {
            session.updateValue(overrideSaltyRtcPort, forKey: "saltyRtcPort")
        }
        return session
    }

    private func deleteSession(_ session: WebClientSessionEntity) {
        sessionManager.stopAndDeleteSession(session)
        if entityManager.entityFetcher.webClientSessionEntities()?.isEmpty ?? true {
            userSettings.threemaWeb = false
            isWebEnabled = false
        }
    }

    private func reloadSessions() {
        do {
            try fetchedResultsController.performFetch()
        }
        catch {
            ErrorHandler.abort(with: error)
        }
        updateSessions()
    }

    private func updateSessions() {
        guard let sessions = fetchedResultsController.fetchedObjects as? [WebClientSessionEntity]
        else {
            return
        }
        self.sessions = sessions
        updateThreemaWebSetting()
    }

    private func updateThreemaWebSetting() {
        if entityManager.entityFetcher.webClientSessionEntities()?.isEmpty ?? true {
            userSettings.threemaWeb = false
            isWebEnabled = false
        }
    }

    private func threemaWebSwitchChanged() {
        userSettings.threemaWeb = isWebEnabled

        if !isWebEnabled {
            sessionManager.stopAllSessions()
            sessionManager.removeAllNotPermanentSessions()
        }
        else {
            if sessions.isEmpty {
                showScanner()
            }
        }
    }

    private func cleanupOldNonPermanentSessions() {
        guard let all = entityManager.entityFetcher.webClientSessionEntities() else {
            return
        }
        
        for session in all {
            if session.permanent.boolValue {
                continue
            }
            if let date = session.lastConnection,
               let hours = Calendar.current.dateComponents([.hour], from: date, to: Date()).hour, hours > 24,
               session.active?.boolValue == false {
                webClientSessionStore.deleteWebClientSession(session)
            }
        }
    }

    private func isWebHostDisallowedForBusinessApp(_ session: [String: Any]) -> Bool {
        guard
            TargetManager.isBusinessApp,
            let hostName = session["saltyRTCHost"] as? String,
            let webHosts = MDMSetup()?.webHosts()
        else {
            return false
        }
        let isWebHostAllowed = WCSessionManager.isWebHostAllowed(scannedHostName: hostName, whiteList: webHosts)
        return !isWebHostAllowed
    }

    private func connectToWebSession(session: [String: Any], authToken: Data) {
        let webClientSession = webClientSessionStore.addWebClientSession(dictionary: session)
        sessionManager.connect(authToken: authToken, wca: nil, webClientSession: webClientSession)
        topViewController.dismiss(animated: true, completion: nil)
    }

    private func updateContactsFeatureMask() async {
        guard let identities = contactStore.contactsWithFeatureMaskNil(), !identities.isEmpty else {
            return
        }
        do {
            try await FeatureMask.updateFeatureMask(for: identities.map { ThreemaIdentity($0) })
        }
        catch {
            DDLogError("Update feature mask failed: \(error)")
        }
    }

    private func showAlertForUnauthorizedSession() {
        let title = #localize("webClient_scan_error_mdm_host_title")
        let message = #localize("webClient_scan_error_mdm_host_message")
        UIAlertTemplate.showAlert(owner: topViewController, title: title, message: message) { [topViewController] _ in
            topViewController.dismiss(animated: true, completion: nil)
        }
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension ThreemaWebSettingsViewModel: @preconcurrency NSFetchedResultsControllerDelegate {
    func controller(
        _ controller: NSFetchedResultsController<NSFetchRequestResult>,
        didChange anObject: Any,
        at indexPath: IndexPath?,
        for type: NSFetchedResultsChangeType,
        newIndexPath: IndexPath?
    ) {
        updateSessions()
    }

    func controller(
        _ controller: NSFetchedResultsController<NSFetchRequestResult>,
        didChange sectionInfo: NSFetchedResultsSectionInfo,
        atSectionIndex sectionIndex: Int,
        for type: NSFetchedResultsChangeType
    ) {
        updateSessions()
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        updateSessions()
    }
}
