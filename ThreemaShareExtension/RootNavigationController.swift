//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2025 Threema GmbH
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
import Intents
import LocalAuthentication
import PromiseKit
import ThreemaFramework
import ThreemaMacros

class RootNavigationController: UINavigationController {
    
    var recipientConversations: Set<ConversationEntity>?
    var passcodeVC: JKLLockScreenViewController?
    var passcodeTryCount = 0
    var isAuthorized = false
    
    var selectedIdentity: ConversationEntity?
    
    let itemLoader = ItemLoader()
    var itemSender = ItemSender()
    
    weak var previewViewController: MediaPreviewViewController?
    weak var picker: ContactGroupPickerViewController?
    weak var progressViewController: ProgressViewController?
    var textPreview: TextPreviewViewController?

    private let dataProcessor = MediaPreviewURLDataProcessor()

    private var evaluatedPolicyDomainState: Data?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        PromiseKitConfiguration.configurePromiseKit()
        
        setAppGroup()
        Colors.initTheme()
        
        if !UserSettings.shared().useSystemTheme {
            overrideUserInterfaceStyle = UserSettings.shared().darkTheme ? .dark : .light
        }
        
        // Check if we already have a suggested contact
        setContactsFromIntent()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        if extensionIsReady() {
            startExtension()
        }
    }
    
    func setContactsFromIntent() {
        if let intent = extensionContext?.intent as? INSendMessageIntent,
           let selectedIdentity = intent.conversationIdentifier as String? {
            if let managedObject = EntityManager().entityFetcher.existingObject(withIDString: selectedIdentity) {
                if let contact = managedObject as? ContactEntity,
                   let conversation = EntityManager().entityFetcher.conversation(for: contact) {
                    self.selectedIdentity = conversation
                    if var recipientConversations {
                        recipientConversations.insert(conversation)
                    }
                    else {
                        recipientConversations = Set<ConversationEntity>()
                        recipientConversations?.insert(conversation)
                    }
                }
                else if let group = managedObject as? ConversationEntity {
                    self.selectedIdentity = group
                    if var recipientConversations {
                        recipientConversations.insert(group)
                    }
                    else {
                        recipientConversations = Set<ConversationEntity>()
                        recipientConversations?.insert(group)
                    }
                }
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        Colors.update(navigationBar: navigationBar)
        
        setAppGroup()
        
        #if DEBUG
            LogManager.initializeGlobalLogger(debug: true)
        #else
            LogManager.initializeGlobalLogger(debug: false)
        #endif
        
        recolorBarButtonItems()

        navigationBar.backgroundColor = Colors.backgroundNavigationController
    }
    
    private func startExtension() {
        ServerConnector.shared().connect(initiator: .shareExtension)
        
        _ = loadItemsFromContext()
        
        if let selectedIdentity {
            recipientConversations = Set<ConversationEntity>()
            recipientConversations?.insert(selectedIdentity)
            presentMediaOrTextPreview()
        }
        else {
            presentContactPicker()
        }
    }
    
    private func loadMediaItems() {
        _ = itemLoader.loadItems().done { items in
            self.presentMediaPreview(with: items as [Any])
        }.catch { err in
            DDLogError("Error: \(err)")
            self.finishAndClose(success: false)
        }
    }
    
    private func optionsEnabled(itemCount: Int, item: Any?) -> Bool {
        guard itemCount == 1 else {
            return true
        }
        guard let urlItem = item as? URL else {
            return true
        }
        let uti = UTIConverter.uti(forFileURL: urlItem)
        return
            UTIConverter.type(uti, conformsTo: UTType.image.identifier) || UTIConverter
                .type(uti, conformsTo: UTType.movie.identifier)
    }
    
    private func presentMediaPreview(with data: [Any]) {
        let storyboardName = "MediaShareStoryboard"
        let storyboardBundle = Bundle(for: MediaPreviewViewController.self)
        let sb = UIStoryboard(name: storyboardName, bundle: storyboardBundle)
        previewViewController = sb
            .instantiateViewController(withIdentifier: "MediaShareController") as? MediaPreviewViewController
        
        guard let previewViewController else {
            let err = "Could not create preview view controller!"
            DDLogError("\(err)")
            fatalError(err)
        }
        
        previewViewController.backIsCancel = true
        previewViewController.sendIsChoose = false
        previewViewController.disableAdd = true
        previewViewController.optionsEnabled = optionsEnabled(itemCount: data.count, item: data.first)
        previewViewController.memoryConstrained = true
        
        if let recipientConversations {
            previewViewController.conversationDescription = ShareExtensionHelpers
                .getDescription(for: Array(recipientConversations).compactMap { $0 })
        }
        
        dataProcessor.cancelAction = { [weak self] in self?.cancelTapped() }
        dataProcessor.memoryConstrained = true
        
        previewViewController.initWithMedia(
            dataArray: data,
            completion: { [weak self] data, sendAsFile, captions in
                guard let dataItems = data as? [URL] else {
                    let err = "Invalid format for data items from media preview"
                    DDLogError("\(err)")
                    fatalError(err)
                }
                
                guard let strongSelf = self else {
                    fatalError()
                }

                strongSelf.itemSender.sendAsFile = sendAsFile
                strongSelf.itemSender.itemsToSend = dataItems
                strongSelf.itemSender.captions = captions
                
                strongSelf.startSending()
            },
            itemDelegate: dataProcessor
        )
        
        pushViewController(previewViewController, animated: true)
        let title = #localize("cancel")
        previewViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: title,
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )
    }
    
    @objc private func cancelTapped() {
        finishAndClose(success: false)
    }
    
    private func presentContactPicker() {
        guard let pickerController = ContactGroupPickerViewController.pickerFromStoryboard(withDelegate: self) else {
            let err = "Could not create sharing UI"
            DDLogError("\(err)")
            fatalError(err)
        }
        
        picker = pickerController.topViewController as? ContactGroupPickerViewController
        guard let picker else {
            let err = "Could not create Contact Picker"
            DDLogError("\(err)")
            fatalError(err)
        }
        picker.delegate = self
        picker.enableMultiSelection = true
        picker.enableTextInput = false
        picker.enableControlView = false
        picker.rightBarButtonTitle = #localize("next")
        picker.delegateDisablesSearchController = true
        
        navigationItem.backBarButtonItem = nil
        
        pushViewController(picker, animated: true)
    }
    
    @objc private func presentMediaOrTextPreview() {
        let itemType = itemLoader.checkItemType()
        
        if itemType == .TextOnly {
            itemLoader.filterTextItems()
            let items = itemLoader.loadItems()
            _ = itemLoader.generatePreviewText(items: items).done { text, range in
                var convs: [ConversationEntity]?
                if let recipientConversations = self.recipientConversations {
                    convs = Array(recipientConversations)
                }
                
                self.presentTextPreview(previewText: text, selectedText: range, conversations: convs)
            }.catch { err in
                // iOS 12 does not allow us to detect whether we are receiving a text file or a regular
                // string. Thus the item loader throws an error if the text turns out to be a file url.
                if err is ItemLoader.TextFileLoaderError {
                    self.loadMediaItems()
                }
                else {
                    DDLogError("Error: \(err)")
                    self.finishAndClose(success: false)
                }
            }
        }
        else if itemType == .Media {
            loadMediaItems()
        }
        else {
            // Not allowed
            let err = "Illegal item type provided"
            DDLogError("\(err)")
            fatalError(err)
        }
    }
    
    @objc private func chooseContacts() {
        guard let pickerController = ContactGroupPickerViewController.pickerFromStoryboard(withDelegate: self) else {
            let err = "Could not create sharing UI"
            DDLogError("\(err)")
            fatalError(err)
        }
        
        picker = pickerController.topViewController as? ContactGroupPickerViewController
        guard let picker else {
            let err = "Could not create Contact Picker"
            DDLogError("\(err)")
            fatalError(err)
        }
        picker.delegate = self
        picker.enableMultiSelection = true
        picker.enableTextInput = false
        picker.enableControlView = false
        
        if let selectedConversation = selectedIdentity {
            picker.preselectedConversations = [selectedConversation]
        }
        
        let backButton = UIBarButtonItem()
        backButton.title = #localize("back")
        navigationItem.backBarButtonItem = backButton
        
        picker.navigationItem.leftBarButtonItem = nil
        
        if textPreview != nil {
            itemSender.textToSend = textPreview!.previewText
        }
        
        pushViewController(picker, animated: true)
        
        recolorBarButtonItems()
        
        isModalInPresentation = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        Colors.update(navigationBar: navigationBar)
        recolorBarButtonItems()
        
        super.viewDidAppear(animated)
    }
    
    /// This takes the left and right bar button items and sets the tintColor and titleTextAttributes back to something
    /// that is legible in our share extension
    private func recolorBarButtonItems() {
        for viewController in children {
            let navItem = viewController.navigationItem
            var items = [UIBarButtonItem]()
            items.append(contentsOf: navItem.leftBarButtonItems ?? [UIBarButtonItem]())
            items.append(contentsOf: navItem.rightBarButtonItems ?? [UIBarButtonItem]())
            
            for item in items {
                let attributes: [NSAttributedString.Key: Any] = [
                    NSAttributedString.Key.foregroundColor: UIColor.tintColor as Any,
                ]
                
                item.setTitleTextAttributes(attributes, for: .normal)
                item.setTitleTextAttributes(attributes, for: .application)
            }
        }
    }
    
    private func presentTextPreview(
        previewText: String?,
        selectedText: NSRange?,
        conversations: [ConversationEntity?]?
    ) {
        var selectedConversations: [ConversationEntity]?
        
        if let conversations {
            selectedConversations = conversations.compactMap { $0 }
        }
        
        textPreview = TextPreviewViewController(
            previewText: previewText,
            selectedText: selectedText,
            selectedConversations: selectedConversations
        )
        
        guard let textPreview else {
            return
        }
        
        textPreview.navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: #localize("send"),
            style: .done,
            target: self,
            action: #selector(sendText)
        )
        
        textPreview.navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: #localize("cancel"),
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )
        
        pushViewController(textPreview, animated: true)
        recolorBarButtonItems()
        
        BrandingUtils.updateTitleLogo(of: textPreview.navigationItem, in: self)
    }
    
    @objc private func sendText() {
        guard let textPreview else {
            return
        }
        
        itemSender.textToSend = textPreview.previewText
        startSending()
    }
    
    private func isDBReady() -> Bool {
        guard let dbManager = DatabaseManager.db() else {
            return false
        }
        
        let requiresMigration = dbManager.storeRequiresMigration()
        return requiresMigration == RequiresMigrationNone
    }

    private func isAppReady() -> Bool {
        !AppMigrationVersion.isMigrationRequired(userSettings: UserSettings.shared())
    }

    func hasLicense() -> Bool {
        LicenseStore.shared().isValid()
    }
    
    private func showNeedStartAppFirst() {
        let title = String.localizedStringWithFormat(
            #localize("need_to_start_app_first_title"),
            TargetManager.appName
        )
        let message = String.localizedStringWithFormat(
            #localize("need_to_start_app_first_message"),
            TargetManager.appName
        )
        showAlert(with: title, message: message, closeOnOK: true)
    }
    
    private func checkPasscode() -> Bool {
        let defaults = AppGroup.userDefaults()
        
        let openTime = Int(defaults!.double(forKey: "UIActivityViewControllerOpenTime"))
        
        var hidePasslock = false
        let maxTimeSinceApp = 10
        let uptime = ThreemaUtilityObjC.systemUptime()
        
        if uptime > 0, openTime > 0, (uptime - openTime) > 0, (uptime - openTime) < maxTimeSinceApp {
            hidePasslock = true
        }
        
        defaults?.removeObject(forKey: "UIActivityViewControllerOpenTime")
        
        let passcodeRequired = KKPasscodeLock.shared()?.isPasscodeRequired() ?? true
        let withinGracePeriod = KKPasscodeLock.shared()?.isWithinGracePeriod() ?? false
        
        if passcodeRequired, !withinGracePeriod, !hidePasslock {
            isAuthorized = false
            
            let str = String(describing: JKLLockScreenViewController.self)
            
            let lockViewController = JKLLockScreenViewController(nibName: str, bundle: BundleUtil.frameworkBundle())
            
            lockViewController.lockScreenMode = .extension
            lockViewController.delegate = self
            
            let navigationController = UINavigationController(rootViewController: lockViewController)
            navigationController.setNavigationBarHidden(true, animated: false)
            
            present(navigationController, animated: true, completion: {
                self.tryTouchIDAuthentication()
            })
            return false
        }
        return true
    }
    
    private func tryTouchIDAuthentication() {
        TouchIDAuthentication.tryCallback { success, error, data in
            if let error = error as? NSError, error.domain == "ThreemaErrorDomain",
               let vc = self.presentedViewController {
                
                self.evaluatedPolicyDomainState = data
                
                Task { @MainActor in
                    let title: String =
                        if LAContext().unlockType() == .faceID {
                            #localize("alert_biometrics_changed_title_face")
                        }
                        else {
                            #localize("alert_biometrics_changed_title_touch")
                        }
                    UIAlertTemplate.showAlert(
                        owner: vc,
                        title: title,
                        message: String.localizedStringWithFormat(
                            #localize("alert_biometrics_changed_message"),
                            TargetManager.appName,
                            TargetManager.appName
                        )
                    ) { _ in
                    }
                }
            }
            
            if success {
                DispatchQueue.main.async {
                    self.showExtension()
                }
            }
        }
    }
    
    private func showExtension() {
        presentedViewController?.dismiss(animated: true, completion: {
            self.startExtension()
        })
    }
    
    private func checkContextItems() -> Bool {
        if extensionContext?.inputItems.isEmpty == true {
            let title = #localize("error_message_no_items_title")
            let message = #localize("error_message_no_items_message")
            showAlert(with: title, message: message, closeOnOK: true)
            return false
        }
        return true
    }
    
    private func extensionIsReady() -> Bool {
        // drop shared instance, otherwise we won't notice any changes to it
        MyIdentityStore.resetSharedInstance()
                
        if !AppSetup.isCompleted {
            showNeedStartAppFirst()
        }
        
        if !hasLicense() {
            showNeedStartAppFirst()
            return false
        }
        
        if !isDBReady() {
            showNeedStartAppFirst()
            return false
        }

        if !isAppReady() {
            showNeedStartAppFirst()
            return false
        }
        
        if !checkPasscode() {
            return false
        }
        
        if !checkContextItems() {
            return false
        }
        
        return true
    }
    
    private func showAlert(with title: String, message: String, closeOnOK: Bool) {
        var vc = viewControllers.last
        if vc == nil {
            vc = self
        }
        guard let viewController = vc else {
            let err = "Could not get view controller to show alert on"
            DDLogError("\(err)")
            fatalError(err)
        }
        UIAlertTemplate.showAlert(owner: viewController, title: title, message: message, actionOk: { _ in
            
            if closeOnOK {
                self.extensionContext!.completeRequest(returningItems: nil, completionHandler: { _ in
                    self.commonCompletionHandler()
                })
            }
        })
    }
    
    private func showAlert(alertController: UIAlertController) {
        if presentedViewController != nil {
            presentedViewController?.present(alertController, animated: true, completion: nil)
        }
        else {
            present(alertController, animated: true, completion: nil)
        }
    }
    
    private func loadItemsFromContext() -> Promise<Void> {
        itemSender = ItemSender()
        itemSender.delegate = self
        
        // We theoretically accept multiple input items, but this is only to allow the share extension to show up
        // when sharing a pdf from Safari. In all other tested cases only one inputItem and multiple attachments are
        // provided.
        // In the case of a pdf from Safari, we are only interested in the pdf and not the url anyways.
        if let item = extensionContext!.inputItems.first as? NSExtensionItem {
            for case let itemProvider in item.attachments! {
                let baseUTI = ItemLoader.getBaseUTIType(itemProvider)
                let secondUTI = ItemLoader.getSecondUTIType(itemProvider, baseType: baseUTI)
                itemLoader.addItem(itemProvider: itemProvider, type: baseUTI, secondType: secondUTI)
            }
        }
        
        return .value
    }
    
    private func canConnect() -> Bool {
        if ServerConnector.shared().connectionState == .loggedIn {
            return true
        }
        
        if !AppGroup.amIActive() {
            setAppGroup()
        }
        
        ServerConnector.shared().connect(initiator: .shareExtension)
        return false
    }
    
    private func setAppGroup() {
        AppGroup.setGroupID(BundleUtil.threemaAppGroupIdentifier())
        AppGroup.setAppID(BundleUtil.threemaAppIdentifier())
        
        AppGroup.setActive(true, for: AppGroupTypeShareExtension)
        AppGroup.setActive(false, for: AppGroupTypeNotificationExtension)

        UserSettings.resetSharedInstance()
        
        AppSetup.registerIfADatabaseFileExists()
    }
    
    private func showProgressUI() {
        _ = itemSender.itemCount().done { itemCount in
            self.progressViewController = self.storyboard!
                .instantiateViewController(withIdentifier: "ProgressViewController") as? ProgressViewController
            guard let progressController = self.progressViewController else {
                DDLogError("Could not find progressViewController")
                self.finishAndClose(success: false)
                return
            }
            
            progressController.delegate = self
            progressController.totalCount = Int(itemCount) * self.recipientConversations!.count
            
            progressController.modalTransitionStyle = .crossDissolve
            
            self.present(progressController, animated: true, completion: {
                self.sendItems()
            })
        }
    }
    
    private func sendItems() {
        popToRootViewController(animated: true)
        itemSender.sendItemsTo(conversations: recipientConversations!)
    }
    
    private func startSending() {
        itemSender.itemCount().then(on: .main) { itemCount -> Promise<Bool> in

            let count = self.recipientConversations!.count * itemCount
            
            if count == 0, itemCount == 0 {
                self.finishAndClose(success: false)
                return .value(false)
            }
            
            if !self.canConnect() {
                let title = #localize("cannot_connect_title")
                let message = #localize("cannot_connect_message")
                self.showAlert(with: title, message: message, closeOnOK: false)

                throw ThreemaProtocolError.notLoggedIn
            }

            return .value(true)
        }.done(on: .main) { showProgress in
            guard showProgress else {
                return
            }
            self.showProgressUI()
        }.catch {
            DDLogError("Start sending failed: \($0)")
        }
    }
    
    private func commonCompletionHandler() {
        AppGroup.setActive(false, for: AppGroupTypeShareExtension)
        forceExit()
    }
    
    private func completionHandler(expired: Bool) {
        if expired {
            itemSender.shouldCancel = true
            ServerConnector.shared().disconnect(initiator: .shareExtension)
        }
        else {
            ServerConnector.shared().disconnectWait(initiator: .shareExtension)
            commonCompletionHandler()
        }
    }
    
    private func cancelAndClose() {
        finishAndClose(success: false)
    }
    
    /// The share extension lives in a process which will be reused when the share extension is launched multiple times.
    /// Since we cannot clear all state, some leftover memory (around 15MB per launch of the SE) will always exist
    /// causing issues when large images are shared.
    private func forceExit() {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.5) {
            DDLogNotice("Force exiting the share extension")
            DDLog.flushLog()
            exit(0)
        }
    }
    
    private func finishAndClose(success: Bool) {
        AppGroup.setActive(false, for: AppGroupTypeShareExtension)
                
        itemLoader.deleteTempDir()
        
        var delay: Double = 0
        
        if progressViewController != nil {
            delay = 0.5
        }
        let when = DispatchTime.now() + delay
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: when) {
            if success {
                DispatchQueue.main.async {
                    let generator = UIImpactFeedbackGenerator()
                    generator.impactOccurred()
                }
            }
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: { expired in
                NotificationCenter.default.removeObserver(self)
                self.completionHandler(expired: expired)
            })
        }
    }
    
    @objc private func didBecomeActive(notification: Notification) {
        AppGroup.setActive(true, for: AppGroupTypeShareExtension)
        AppGroup.setActive(false, for: AppGroupTypeNotificationExtension)
    }
}

// MARK: - ContactGroupPickerDelegate

extension RootNavigationController: ContactGroupPickerDelegate {

    func contactPicker(
        _ contactPicker: ContactGroupPickerViewController!,
        didPickConversations conversations: Set<AnyHashable>!,
        renderType: NSNumber!,
        sendAsFile: Bool
    ) {
        recipientConversations = Set<ConversationEntity>()
        
        if contactPicker.additionalTextToSend != nil {
            itemSender.addText(text: contactPicker.additionalTextToSend)
        }
        
        for case let conversation as ConversationEntity in conversations {
            recipientConversations?.insert(conversation)
        }
        
        presentMediaOrTextPreview()
    }
    
    func contactPickerDidCancel(_ contactPicker: ContactGroupPickerViewController!) {
        cancelAndClose()
    }
    
    override func popViewController(animated: Bool) -> UIViewController? {
        isModalInPresentation = false
        return super.popViewController(animated: animated)
    }
}

// MARK: - JKLLockScreenViewControllerDelegate

extension RootNavigationController: JKLLockScreenViewControllerDelegate {
    
    func shouldEraseApplicationData(_ viewController: JKLLockScreenViewController!) {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: { _ in
            self.commonCompletionHandler()
        })
    }
    
    func didPasscodeEnteredIncorrectly(_ viewController: JKLLockScreenViewController!) {
        if passcodeTryCount >= 3 {
            extensionContext?.completeRequest(returningItems: nil, completionHandler: { _ in
                self.commonCompletionHandler()
            })
        }
        passcodeTryCount = passcodeTryCount + 1
    }
    
    func didPasscodeEnteredCorrectly(_ viewController: JKLLockScreenViewController!) {
        
        if let evaluatedPolicyDomainState {
            UserSettings.shared().evaluatedPolicyDomainStateShareExtension = evaluatedPolicyDomainState
            self.evaluatedPolicyDomainState = nil
        }
        
        isAuthorized = true
    }
    
    func unlockWasCancelledLockScreenViewController(_ lockScreenViewController: JKLLockScreenViewController!) {
        finishAndClose(success: false)
    }
    
    func didPasscodeViewDismiss(_ viewController: JKLLockScreenViewController!) {
        if isAuthorized {
            startExtension()
        }
    }
}

// MARK: - ProgressViewDelegate

extension RootNavigationController: ProgressViewDelegate {
    func progressViewDidCancel() {
        itemSender.shouldCancel = true
        
        DispatchQueue.main.async {
            self.finishAndClose(success: false)
        }
    }
}

// MARK: - ModalNavigationControllerDelegate

extension RootNavigationController: ModalNavigationControllerDelegate {
    func didDismissModalNavigationController() {
        finishAndClose(success: false)
    }
}

// MARK: - SenderItemDelegate

extension RootNavigationController: SenderItemDelegate {
    func showAlert(with title: String, message: String) {
        DispatchQueue.main.async {
            self.showAlert(with: title, message: message, closeOnOK: true)
        }
    }
    
    func setProgress(progress: NSNumber, forItem: Any) {
        // TODO: IOS-2707 Something with progress reporting is broken
//        progressViewController?.setProgress(progress: progress, item: forItem)
    }
    
    func finishedItem(item: Any) {
        progressViewController?.finishedItem(item: item)
    }
    
    func setFinished() {
        finishAndClose(success: true)
    }
}
