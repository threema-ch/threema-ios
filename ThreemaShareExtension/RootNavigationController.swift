//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2021 Threema GmbH
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

import Foundation
import ThreemaFramework
import CocoaLumberjackSwift
import PromiseKit

class RootNavigationController : UINavigationController {
    
    var recipientConversations : Set<Conversation>?
    var passcodeVC : JKLLockScreenViewController?
    var passcodeTryCount : Int = 0
    var isAuthorized : Bool = false
    
    let itemLoader = ItemLoader()
    var itemSender = ItemSender()
    
    
    unowned var previewViewController : MediaPreviewViewController?
    unowned var picker : ContactGroupPickerViewController?
    unowned var progressViewController : ProgressViewController?
    unowned var textPreview : TextPreviewViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        AppGroup.setGroupId(BundleUtil.threemaAppGroupIdentifier())
        AppGroup.setAppId(BundleUtil.threemaAppIdentifier())
        
        _ = AppSetupState()
        
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        
        if self.extensionIsReady() {
            self.startExtension()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        Colors.update(self.navigationBar)
        
        UserSettings.resetSharedInstance()
        
        AppGroup.setActive(true, for: AppGroupTypeShareExtension)
        
        #if DEBUG
        LogManager.initializeGlobalLogger(debug: true)
        #else
        LogManager.initializeGlobalLogger(debug: false)
        #endif
        
        self.recolorBarButtonItems()
        self.navigationBar.backgroundColor = Colors.background()
    }
    
    private func startExtension() {
        ServerConnector.shared()?.connect()
        
        _ = self.loadItemsFromContext()
        
        let itemType = itemLoader.checkItemType()
        
        if itemType == .TextOnly {
            itemLoader.filterTextItems()
            let items = itemLoader.loadItems()
            _ = itemLoader.generatePreviewText(items: items).done { (text, range) in
                self.presentTextPreview()
                self.textPreview?.previewText = text
                self.textPreview?.selectedText = range
            }.catch { err in
                DDLogError("Error: \(err)")
                self.finishAndClose(success: false)
            }
        } else if itemType == .Media {
            _ = itemLoader.loadItems().done({ (items) in
                self.presentMediaPreview(with: items as [Any])
            }).catch { err in
                DDLogError("Error: \(err)")
                self.finishAndClose(success: false)
            }
        } else {
            // Not allowed
            let err = "illegal item type provided"
            DDLogError(err)
            fatalError(err)
        }
    }
    
    private func optionsEnabled(itemCount : Int, item : Any?) -> Bool {
        guard itemCount == 1 else {
            return true
        }
        guard let urlItem = item as? URL else {
            return true
        }
        let uti = UTIConverter.uti(forFileURL: urlItem)
        return (UTIConverter.type(uti, conformsTo: kUTTypeImage as String) || UTIConverter.type(uti, conformsTo: kUTTypeMovie as String))
    }
    
    private func presentMediaPreview(with data : [Any]) {
        let storyboardName = "MediaShareStoryboard"
        let storyboardBundle = Bundle(for: MediaPreviewViewController.self)
        let sb = UIStoryboard(name: storyboardName, bundle: storyboardBundle)
        previewViewController = sb.instantiateViewController(withIdentifier: "MediaShareController") as? MediaPreviewViewController
        
        guard let previewViewController = previewViewController else {
            let err = "Could not create preview view controller!"
            DDLogError(err)
            fatalError(err)
        }
        
        previewViewController.backIsCancel = true
        previewViewController.sendIsChoose = true
        previewViewController.disableAdd = true
        previewViewController.optionsEnabled = self.optionsEnabled(itemCount: data.count, item: data.first)
        previewViewController.memoryConstrained = true
        
        let dataProcessor = MediaPreviewURLDataProcessor()
        dataProcessor.cancelAction = {[weak self] in self?.cancelAndClose()}
        dataProcessor.memoryConstrained = true
        
        previewViewController.initWithMedia(dataArray: data, delegate: self, completion: { [weak self] (data, sendAsFile, captions) in
            guard let dataItems = data as? [URL] else {
                let err = "Invalid format for data items from media preview"
                DDLogError(err)
                fatalError(err)
            }
            self?.itemSender.sendAsFile = sendAsFile
            self?.itemSender.itemsToSend = dataItems
            self?.itemSender.captions = captions
            self?.chooseContacts()
        }, itemDelegate: dataProcessor)
        
        self.pushViewController(previewViewController, animated: true)
        let title = BundleUtil.localizedString(forKey: "cancel")
        previewViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(title: title, style: .plain, target: self, action: #selector(cancelTapped))
    }
    
    @objc private func cancelTapped() {
        self.finishAndClose(success: false)
    }
    
    @objc private func chooseContacts() {
        guard let pickerController = ContactGroupPickerViewController.pickerFromStoryboard(withDelegate: self) else {
            let err = "Could not create sharing UI"
            DDLogError(err)
            fatalError(err)
        }
        
        picker = pickerController.topViewController as? ContactGroupPickerViewController
        guard let picker = picker else {
            let err = "Could not create Contact Picker"
            DDLogError(err)
            fatalError(err)
        }
        picker.delegate = self
        picker.enableMultiSelection = true
        picker.enableTextInput = false
        picker.enableControlView = false
        
        let backButton = UIBarButtonItem()
        backButton.title = BundleUtil.localizedString(forKey: "back")
        navigationItem.backBarButtonItem = backButton
        
        picker.navigationItem.leftBarButtonItem = nil
        
        if textPreview != nil {
            self.itemSender.textToSend = textPreview!.previewText
        }
        
        self.pushViewController(picker, animated: true)
        recolorBarButtonItems()
    }
    
    @objc private func popBack() {
        self.popViewController(animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        Colors.update(self.navigationBar)
        self.recolorBarButtonItems()
        
        super.viewDidAppear(animated)
    }
    
    /// This takes the left and right bar button items and sets the tintColor and titleTextAttributes back to something that is legible in our share extension
    private func recolorBarButtonItems() {
        for viewController in self.children {
            let navItem = viewController.navigationItem
            var items = [UIBarButtonItem]()
            items.append(contentsOf: navItem.leftBarButtonItems ?? [UIBarButtonItem]())
            items.append(contentsOf: navItem.rightBarButtonItems ?? [UIBarButtonItem]())
            
            for item in items {
                let attributes : [NSAttributedString.Key : Any] = [
                    NSAttributedString.Key.foregroundColor : Colors.main() as Any,
                ]
                
                item.setTitleTextAttributes(attributes , for: .normal)
                item.setTitleTextAttributes(attributes, for: .application)
                item.tintColor = Colors.main()
            }
        }
    }
    
    private func presentTextPreview() {
        let storyboard = UIStoryboard(name: "ThreemaShareStoryboard", bundle: nil)
        textPreview = (storyboard.instantiateViewController(withIdentifier: "TextPreviewViewController") as! TextPreviewViewController)
        textPreview!.navigationItem.rightBarButtonItem = UIBarButtonItem(title: BundleUtil.localizedString(forKey: "next"), style: .done, target: self, action: #selector(chooseContacts))
        textPreview!.navigationItem.leftBarButtonItem = UIBarButtonItem(title: BundleUtil.localizedString(forKey: "cancel"), style: .plain, target: self, action: #selector(cancelTapped))
        
        self.pushViewController(textPreview!, animated: true)
        recolorBarButtonItems()
        
        BrandingUtils.updateTitleLogo(of: textPreview!.navigationItem, navigationController: self)
    }
    
    private func isDBReady() -> Bool {
        guard let dbManager = DatabaseManager.db() else {
            return false
        }
        
        if dbManager.storeRequiresMigration() {
            return false
        }
        
        return true
    }
    
    func hasLicense() -> Bool {
        guard let ls = LicenseStore.shared() else {
            return false
        }
        return ls.isValid()
    }
    
    private func showNeedStartAppFirst() {
        let title = BundleUtil.localizedString(forKey:"need_to_start_app_first_title")
        let message = BundleUtil.localizedString(forKey:"need_to_start_app_first_message")
        self.showAlert(with: title, message: message, closeOnOK: true)
    }
    
    private func checkPasscode() -> Bool {
        let defaults = AppGroup.userDefaults()
        
        let openTime = Int(defaults!.double(forKey: "UIActivityViewControllerOpenTime"))
        
        var hidePasslock = false
        let maxTimeSinceApp = 10
        let uptime = Utils.systemUptime()
        
        if uptime > 0 && openTime > 0 && (uptime - openTime) > 0 && (uptime - openTime) < maxTimeSinceApp {
            hidePasslock = true
        }
        
        defaults?.removeObject(forKey: "UIActivityViewControllerOpenTime")
        
        let passcodeRequired = KKPasscodeLock.shared()?.isPasscodeRequired() ?? true
        let withinGracePeriod = KKPasscodeLock.shared()?.isWithinGracePeriod() ?? false
        
        if passcodeRequired && !withinGracePeriod && !hidePasslock {
            isAuthorized = false
            
            
            let str = String(describing: JKLLockScreenViewController.self)
            
            let lockViewController = JKLLockScreenViewController(nibName: str, bundle: BundleUtil.frameworkBundle())
            
            lockViewController.lockScreenMode = .extension
            lockViewController.delegate = self
            
            let navigationController = UINavigationController(rootViewController: lockViewController)
            navigationController.setNavigationBarHidden(true, animated: false)
            
            self.present(navigationController, animated: true, completion: {
                self.tryTouchIdAuthentication()
            })
            return false
        }
        return true
    }
    
    private func tryTouchIdAuthentication() {
        TouchIdAuthentication.tryCallback({ (success, error) in
            if success {
                DispatchQueue.main.async {
                    self.showExtension()
                }
            }
        })
    }
    
    private func showExtension() {
        self.presentedViewController?.dismiss(animated: true, completion: {
            self.startExtension()
        })
    }
    
    private func checkContextItems() -> Bool {
        if self.extensionContext?.inputItems.count == 0 {
            let title = BundleUtil.localizedString(forKey:"error_message_no_items_title")
            let message = BundleUtil.localizedString(forKey:"error_message_no_items_message")
            self.showAlert(with: title, message: message, closeOnOK: true)
            return false
        }
        return true
    }
    
    private func extensionIsReady() -> Bool {
        // drop shared instance, otherwise we won't notice any changes to it
        MyIdentityStore.resetSharedInstance()
        
        let appSetupState = AppSetupState(myIdentityStore: MyIdentityStore.shared())
        
        if !appSetupState.isAppSetupCompleted() {
            self.showNeedStartAppFirst()
        }
        
        if !hasLicense() {
            showNeedStartAppFirst()
            return false
        }
        
        if !isDBReady() {
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
    
    private func showAlert(with title: String, message : String, closeOnOK : Bool) {
        var vc = self.viewControllers.last
        if vc == nil {
            vc = self
        }
        guard let viewController = vc else {
            let err = "Could not get view controller to show alert on"
            DDLogError(err)
            fatalError(err)
        }
        UIAlertTemplate.showAlert(owner: viewController, title: title, message: message, actionOk: { _ in
            
            if closeOnOK {
                self.extensionContext!.completeRequest(returningItems: nil, completionHandler: { _  in
                    self.commonCompletionHandler()
                })
            }
        })
    }
    
    private func showAlert(alertController : UIAlertController) {
        if (self.presentedViewController != nil) {
            self.presentedViewController?.present(alertController, animated: true, completion: nil)
        } else {
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    private func loadItemsFromContext() -> Promise<Void> {
        self.itemSender = ItemSender()
        itemSender.delegate = self
        
        // We theoretically accept multiple input items, but this is only to allow the share extension to show up
        // when sharing a pdf from Safari. In all other tested cases only one inputItem and multiple attachments are provided.
        // In the case of a pdf from Safari, we are only interested in the pdf and not the url anyways.
        if let item = self.extensionContext!.inputItems.first as? NSExtensionItem {
            for case let itemProvider in item.attachments! {
                let baseUTI = ItemLoader.getBaseUTIType(itemProvider)
                let secondUTI = ItemLoader.getSecondUTIType(itemProvider)
                itemLoader.addItem(itemProvider: itemProvider, type: baseUTI, secondType: secondUTI)
            }
        }
        
        return .value
    }
    
    private func canConnect() -> Bool {
        if ServerConnector.shared()?.connectionState == ConnectionStateLoggedIn {
            return true
        }
        
        ServerConnector.shared()?.connect()
        return false
    }
    
    private func showProgressUI() {
        _ = itemSender.itemCount().done { itemCount in
            self.progressViewController = self.storyboard!.instantiateViewController(withIdentifier: "ProgressViewController") as? ProgressViewController
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
        self.popToRootViewController(animated: true)
        self.itemSender.sendItemsTo(conversations: self.recipientConversations!)
    }
    
    private func startSending() {
        itemSender.itemCount().done { itemCount in
            let count = self.recipientConversations!.count * itemCount
            
            if count == 0, itemCount == 0 {
                self.finishAndClose(success: false)
            }
            
            if !self.canConnect() {
                let title = BundleUtil.localizedString(forKey:"cannot_connect_title")
                let message = BundleUtil.localizedString(forKey:"cannot_connect_message")
                self.showAlert(with: title, message: message, closeOnOK: false)
            }
        }.ensure(on: DispatchQueue.main) {
            self.showProgressUI()
        }.catch { err in
            DDLogError("Unknown error occurred")
        }
    }
    
    private func commonCompletionHandler() {
        AppGroup.setActive(false, for: AppGroupTypeShareExtension)
        forceExit()
    }
    
    private func completionHandler(expired : Bool) {
        if expired {
            itemSender.shouldCancel = true;
            ServerConnector.shared()?.disconnect()
        } else {
            ServerConnector.shared()?.disconnectWait()
        }
        self.commonCompletionHandler()
    }
    
    private func cancelAndClose() {
        self.finishAndClose(success: false)
    }
    
    /// The share extension lives in a process which will be reused when the share extension is launched multiple times.
    /// Since we cannot clear all state, some leftover memory (around 15MB per launch of the SE) will always exist causing issues when large images are shared.
    private func forceExit() {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.5) {
            DDLogNotice("Force exiting the share extension")
            DDLog.flushLog()
            exit(0)
        }
    }
    
    private func finishAndClose(success : Bool) {
        AppGroup.setActive(false, for: AppGroupTypeShareExtension)
        
        MessageQueue.shared()?.save()
        
        self.itemLoader.deleteTempDir()
        
        var delay : Double = 0
        
        if progressViewController != nil {
            delay = 0.5
        }
        let when = DispatchTime.now() + delay
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: when, execute: {
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
        })
    }
    
    @objc private func didBecomeActive(notification : Notification) {
        AppGroup.setActive(true, for: AppGroupTypeShareExtension)
    }
}

//MARK: - ContactGroupPickerDelegate

extension RootNavigationController : ContactGroupPickerDelegate {
    func contactPicker(_ contactPicker: ContactGroupPickerViewController!, didPickConversations conversations: Set<AnyHashable>!, renderType: NSNumber!, sendAsFile: Bool) {
        recipientConversations = Set<Conversation>()
        
        if (contactPicker.additionalTextToSend != nil) {
            itemSender.addText(text: contactPicker.additionalTextToSend)
        }
        for case let conversation as Conversation in conversations {
            recipientConversations?.insert(conversation)
        }
        
        self.startSending()
    }
    
    func contactPickerDidCancel(_ contactPicker: ContactGroupPickerViewController!) {
        self.popViewController(animated: true)
    }
}

// MARK: - Passcode lock delegate


extension RootNavigationController : JKLLockScreenViewControllerDelegate {
    
    func shouldEraseApplicationData(_ viewController: JKLLockScreenViewController!) {
        self.extensionContext?.completeRequest(returningItems: nil, completionHandler: { _ in
            self.commonCompletionHandler()
        })
    }
    
    func didPasscodeEnteredIncorrectly(_ viewController: JKLLockScreenViewController!) {
        if passcodeTryCount >= 3 {
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: { _ in
                self.commonCompletionHandler()
            })
        }
        passcodeTryCount = passcodeTryCount + 1
    }
    
    func didPasscodeEnteredCorrectly(_ viewController: JKLLockScreenViewController!) {
        isAuthorized = true
    }
    
    func unlockWasCancelledLockScreenViewController(_ lockScreenViewController: JKLLockScreenViewController!) {
        self.finishAndClose(success: false)
    }
    
    func didPasscodeViewDismiss(_ viewController: JKLLockScreenViewController!) {
        if isAuthorized {
            self.startExtension()
        }
    }
}

//MARK: - ProgressViewDelegate

extension RootNavigationController : ProgressViewDelegate {    
    func progressViewDidCancel() {
        itemSender.shouldCancel = true
        
        DispatchQueue.main.async {
            self.finishAndClose(success: false)
        }
    }
}

//MARK: - ModalNavigationControllerDelegate

extension RootNavigationController : ModalNavigationControllerDelegate {
    func willDismissModalNavigationController() {
        self.finishAndClose(success: false)
    }
}

//MARK: - SenderItemDelegate

extension RootNavigationController : SenderItemDelegate {
    func showAlert(with title: String, message: String) {
        DispatchQueue.main.async {
            self.showAlert(with: title, message: message, closeOnOK: true)
        }
    }
    
    func setProgress(progress: NSNumber, forItem: Any) {
        progressViewController?.setProgress(progress: progress, item: forItem)
    }
    
    func finishedItem(item: Any) {
        progressViewController?.finishedItem(item: item)
    }
    
    func setFinished() {
        self.finishAndClose(success: true)
    }
}
