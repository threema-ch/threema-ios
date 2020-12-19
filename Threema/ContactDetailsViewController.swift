//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2020 Threema GmbH
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
import QuartzCore
import Contacts
import ContactsUI

@objc protocol ContactDetailsViewControllerDelegate: class {
    @objc func present(contactDetailsViewController: ContactDetailsViewController, onCompletion: @escaping ((_ contactsDetailsViewController: ContactDetailsViewController) -> Void))
}

class ContactDetailsViewController: ThemedTableViewController {
    
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var disclosureButton: UIButton!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    
    @IBOutlet weak var companyNameLabel: UILabel!
    @IBOutlet weak var threemaTypeIcon: UIButton!
    @IBOutlet weak var scanQrCodeBarButtonItem: UIBarButtonItem!
    
    @objc var contact: Contact?
    @objc var hideActionButtons: Bool = false
    @objc weak var delegate : ContactDetailsViewControllerDelegate?
    
    private var didHideTabBar: Bool = false
    private var callNumbers: [String]?
    private var cnAddressBook: CNContactStore = CNContactStore()
    private var cnContact: CNContact?
    private var cnContactViewShowing: Bool = false
    private var canExportConversation: Bool = false
    private var conversation: Conversation?
    
    private var showcase: MaterialShowcase?
    
    private var kvoContact: NSKeyValueObservation?
        
    private let THREEMA_ID_SHARE_LINK = "https://threema.id/"
    
    override internal var shouldAutorotate : Bool {
        return true
    }
    
    override internal var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return UIInterfaceOrientationMask.all
        }
        return UIInterfaceOrientationMask.allButUpsideDown
    }
    
    override internal var previewActionItems: [UIPreviewActionItem] {
        let sendMessageAction = UIPreviewAction.init(title: BundleUtil.localizedString(forKey: "send_message"), style: .default) { (action, previewController) in
            self.sendMessageAction()
        }
        let scanQrCodeAction = UIPreviewAction.init(title: BundleUtil.localizedString(forKey: "scan_qr"), style: .default) { (action, previewController) in
            // we need to present contact details first and present qr scanner on top of that
            self.delegate?.present(contactDetailsViewController: self, onCompletion: { (contactsDetailsViewController) in
                contactsDetailsViewController.scanIdentityAction()
            })
        }
        
        return [sendMessageAction, scanQrCodeAction]
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
                
        if ScanIdentityController.canScan() == false {
            navigationItem.rightBarButtonItem = nil
        }
        
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
        
        NotificationCenter.default.addObserver(forName: Notification.Name(kNotificationColorThemeChanged), object: nil, queue: nil) { (notification) in
            self.setupColors()
        }
        NotificationCenter.default.addObserver(forName: Notification.Name(kNotificationShowProfilePictureChanged), object: nil, queue: nil) { (notification) in
            self.updateView()
        }
        
        let disclosureTapRecognizer = UITapGestureRecognizer.init(target: self, action: #selector(tappedHeaderView))
        disclosureButton.addGestureRecognizer(disclosureTapRecognizer)
        disclosureButton.accessibilityLabel = BundleUtil.localizedString(forKey: "edit_contact")
        
        let tapRecognizer = UITapGestureRecognizer.init(target: self, action: #selector(tappedImage))
        imageView.addGestureRecognizer(tapRecognizer)
        
        threemaTypeIcon.setTitle("", for: .normal)
        threemaTypeIcon.setBackgroundImage(Utils.threemaTypeIcon(), for: .normal)
        
        setupColors()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if cnContactViewShowing {
            cnContactViewShowing = false
            ContactStore.shared()?.update(contact)
            let statusNavigationBar = navigationController?.navigationBar as! StatusNavigationBar
            statusNavigationBar.showOrHideStatusView()
            Colors.update(navigationController?.navigationBar)
        }
        
        view.alpha = 1.0
        updateView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if navigationController != nil {
            if navigationController!.isNavigationBarHidden {
                navigationController?.isNavigationBarHidden = false
            }
        }
                
        if UserSettings.shared().workInfoShown == false && !Utils.hideThreemaTypeIcon(for: contact) {
            showWorkInfo()
        }
        
        if #available(iOS 13.0, *) {
            kvoContact = contact!.observe(\.verificationLevel, options: .new) { (changedContact, change) in
                DispatchQueue.main.async {
                    self.updateView()
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if #available(iOS 13.0, *) {
            kvoContact?.invalidate()
        }
    }
            
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        let fontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .title3)
        nameLabel.font = UIFont.boldSystemFont(ofSize: fontDescriptor.pointSize)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "EditName" {
            let editVC = segue.destination as? EditContactViewController
            editVC?.contact = contact
        }
        else if segue.identifier == "ShowPushSetting" {
            let notificationSettingViewController = segue.destination as? NotificationSettingViewController
            notificationSettingViewController?.identity = contact?.identity
            notificationSettingViewController?.isGroup = false
            notificationSettingViewController?.conversation = conversation
        }
    }
}

extension ContactDetailsViewController {
    // MARK: public functions
    
    @objc public func sendMessageAction() {
        if let selectedRow = self.tableView!.indexPathForSelectedRow {
            self.tableView.deselectRow(at: selectedRow, animated: true)
        }
        let info: [AnyHashable: Any] = [kKeyContact : contact!, kKeyForceCompose: NSNumber.init(value: true)]
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: kNotificationShowConversation), object: nil, userInfo: info)
    }
    
    @objc public func scanIdentityAction() {
        let scanController = ScanIdentityController.init()
        scanController.containingViewController = self
        scanController.expectedIdentity = contact?.identity
        scanController.popupScanResults = false
        scanController.startScan()
    }
    
    @objc public func startProfilePictureAction() {
        let sender = ContactPhotoSender.init()
        sender.startWithImage(toMember: contact, onCompletion: {
            UIAlertTemplate .showAlert(owner: self, title: BundleUtil.localizedString(forKey: "my_profilepicture"), message: BundleUtil.localizedString(forKey: "contact_send_profilepicture_success"))
        }) { (error) in
            UIAlertTemplate .showAlert(owner: self, title: BundleUtil.localizedString(forKey: "my_profilepicture"), message: BundleUtil.localizedString(forKey: "contact_send_profilepicture_error"))
        }
        if let selectedRow = self.tableView!.indexPathForSelectedRow {
            self.tableView.deselectRow(at: selectedRow, animated: true)
        }
    }
    
    @objc public func startThreemaCallAction(_ startWithVideo: Bool = false) {
        if VoIPCallStateManager.shared.currentCallState() == .idle {
            var contactSet = Set<Contact>()
            contactSet.insert(contact!)
            
            FeatureMask.check(Int(FEATURE_MASK_VOIP), forContacts: contactSet) { (unsupportedContacts) in
                if let selectedRow = self.tableView!.indexPathForSelectedRow {
                    self.tableView.deselectRow(at: selectedRow, animated: true)
                }
                if unsupportedContacts == nil {
                    UIAlertTemplate.showAlert(owner: self, title: BundleUtil.localizedString(forKey: "call_voip_not_supported_title"), message: BundleUtil.localizedString(forKey: "call_voip_not_supported_text"))
                    return
                }
                
                if unsupportedContacts!.count == 0 {
                    self.startVoipCall(startWithVideo)
                } else {
                    UIAlertTemplate.showAlert(owner: self, title: BundleUtil.localizedString(forKey: "call_voip_not_supported_title"), message: BundleUtil.localizedString(forKey: "call_voip_not_supported_text"))
                }
            }
        } else {
            if let selectedRow = self.tableView!.indexPathForSelectedRow {
                self.tableView.deselectRow(at: selectedRow, animated: true)
            }
        }
    }
}

extension ContactDetailsViewController {
    // MARK: private functions
    
    private func setupColors() {
        nameLabel.textColor = Colors.fontNormal()
        nameLabel.shadowColor = nil
        
        companyNameLabel.textColor = Colors.fontNormal()
        companyNameLabel.shadowColor = nil
        
        let disclosureImage: UIImage
        if #available(iOS 13.0, *) {
            disclosureImage = disclosureButton.imageView!.image!.withTintColor(Colors.main())
        } else {
            disclosureImage = disclosureButton.imageView!.image!.withTint(Colors.main())
        }
        disclosureButton.setImage(disclosureImage, for: .normal)
                
        if #available(iOS 11.0, *) {
            imageView.accessibilityIgnoresInvertColors = true
            threemaTypeIcon.accessibilityIgnoresInvertColors = true
        }
    }
    
    private func updateView() {
        if scanQrCodeBarButtonItem != nil {
            scanQrCodeBarButtonItem.accessibilityLabel = BundleUtil.localizedString(forKey: "scan_identity")
        }
                
        navigationItem.title = contact?.displayName
        nameLabel.text = contact?.displayName
        headerView.accessibilityLabel = contact?.displayName
        
        imageView.image = AvatarMaker.shared()?.avatar(for: contact, size: imageView.frame.size.width, masked: false)
        imageView.contentMode = .scaleAspectFill
        imageView.layer.masksToBounds = true
        imageView.layer.cornerRadius = imageView.bounds.size.width / 2
        
        threemaTypeIcon.isHidden = Utils.hideThreemaTypeIcon(for: contact)
        
        companyNameLabel.text = ""
        cnContact = nil
        
        if contact?.cnContactId != nil {
            updateViewWithCNContact()
        }
        
        companyNameLabel.isHidden = companyNameLabel.text?.count == 0
        let headerHeight: CGFloat = companyNameLabel.text?.count == 0 ? 275.0 : 300.0
        headerView.frame = CGRect.init(x: headerView.frame.origin.x, y: headerView.frame.origin.y, width: headerView.frame.size.width, height: headerHeight)
        
        isExportConversationEnabled()
                
        if didHideTabBar {
            tabBarController?.tabBar.isHidden = false
            didHideTabBar = false
        }
        tableView.reloadData()
    }
        
    private func updateViewWithCNContact() {
        cnAddressBook.requestAccess(for: .contacts) { (granted, error) in
            if granted {
                let predicate: NSPredicate = CNContact.predicateForContacts(withIdentifiers: [(self.contact!.cnContactId)])
                let cnContactKeys = [CNContactFamilyNameKey, CNContactGivenNameKey, CNContactMiddleNameKey, CNContactOrganizationNameKey, CNContactPhoneNumbersKey, CNContactEmailAddressesKey, CNContactImageDataKey, CNContactImageDataAvailableKey, CNContactThumbnailImageDataKey, CNContactFormatter.descriptorForRequiredKeys(for: .fullName), CNContactViewController.descriptorForRequiredKeys()] as [Any]
                do {
                    let contacts = try self.cnAddressBook.unifiedContacts(matching: predicate, keysToFetch: cnContactKeys as! [CNKeyDescriptor])
                    if contacts.count > 0 {
                        self.cnContact = contacts.first
                        self.phoneCallNumbers()
                        DispatchQueue.main.async {
                            self.companyNameLabel.text = self.cnContact?.organizationName
                            self.tableView.reloadData()
                        }
                    }
                    
                }
                catch let err{
                    DDLogNotice("Can't get CNContact form addressbook \(err.localizedDescription)")
                }
                
            }
        }
    }
    
    private func phoneCallNumbers() {
        if cnContact != nil {
            callNumbers = nil
            callNumbers = [String]()
            for phone: CNLabeledValue in cnContact!.phoneNumbers {
                let number = phone.value.stringValue
                if callNumbers!.contains(number) {
                    continue
                }
                callNumbers?.append(number)
            }
        }
    }
    
    private func isExportConversationEnabled() {
        let mdmSetup = MDMSetup.init(setup: false)
        let entityManager = EntityManager.init()
        conversation = entityManager.entityFetcher.conversation(for: contact)
        canExportConversation = conversation != nil && !mdmSetup!.disableExport()
    }
    
    @objc private func tappedImage() {
        if contact != nil {
            var image: UIImage?
            if (contact!.contactImage != nil && UserSettings.shared().showProfilePictures) {
                image = UIImage.init(data: contact!.contactImage.data)
            }
            else if contact!.imageData != nil {
                image = UIImage.init(data: contact!.imageData)
            }
            
            if image != nil {
                guard let imageController = FullscreenImageViewController.init(for: image) else { return }
                
                if UIDevice.current.userInterfaceIdiom == .pad {
                    let nav = ModalNavigationController.init(rootViewController: imageController)
                    nav.showDoneButton = true
                    nav.showFullScreenOnIPad = true
                    present(nav, animated: true, completion: nil)
                } else {
                    navigationController?.pushViewController(imageController, animated: true)
                }
            } else {
                tappedHeaderView()
            }
        }
    }
    
    @objc private func tappedHeaderView() {
        if contact != nil {            
            if cnContact != nil {
                let personVC = CNContactViewController.init(for: cnContact!)
                personVC.allowsActions = true
                personVC.allowsEditing = true
                cnContactViewShowing = true
                
                if tabBarController?.tabBar.isHidden == false {
                    didHideTabBar = true
                    tabBarController?.tabBar.isHidden = true
                }
                let statusNavigationBar = navigationController?.navigationBar as! StatusNavigationBar
                statusNavigationBar.hideStatusView()
                navigationController?.navigationBar.barStyle = .default
                navigationController?.pushViewController(personVC, animated: true)
            } else {
                showEditContactVC()
            }
        }
    }
    
    private func showEditContactVC() {
        let editVC = storyboard!.instantiateViewController(withIdentifier: "EditContactViewController") as! EditContactViewController
        editVC.contact = contact
        navigationController?.pushViewController(editVC, animated: true)
    }
    
    private func conversationAction(sender: Any?) {
        let title = String(format: BundleUtil.localizedString(forKey: "include_media_title"), kExportConversationMediaSizeLimit)
        let actionSheet = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: BundleUtil.localizedString(forKey: "include_media"), style: .default, handler: { (action) in
            let em = EntityManager()
            let exporter = ConversationExporter(viewController: self, contact: self.contact!, entityManager: em, withMedia: true)
            exporter.exportConversation()
            
        }))
        
        actionSheet.addAction(UIAlertAction(title: BundleUtil.localizedString(forKey: "without_media"), style: .default, handler: { (action) in
            let em = EntityManager()
             let exporter = ConversationExporter(viewController: self, contact: self.contact!, entityManager: em, withMedia: false)
             exporter.exportConversation()
        }))
        
        actionSheet.addAction(UIAlertAction(title: BundleUtil.localizedString(forKey: "cancel"), style: .cancel, handler: { (action) in
            self.tableView.deselectRow(at: IndexPath.init(row: 1, section: 1), animated: true)
        }))
        
        if sender is UIView {
            let senderView = sender as! UIView
            actionSheet.popoverPresentationController?.sourceRect = senderView.frame
            actionSheet.popoverPresentationController?.sourceView = view
        }
        AppDelegate.shared()?.currentTopViewController()?.present(actionSheet, animated: true, completion: nil)
        if let selectedRow = self.tableView!.indexPathForSelectedRow {
            self.tableView.deselectRow(at: selectedRow, animated: true)
        }
    }
    
    private func startVoipCall(_ startWithVideo: Bool = false) {
        if let selectedRow = self.tableView!.indexPathForSelectedRow {
            self.tableView.deselectRow(at: selectedRow, animated: true)
        }
        
        if ServerConnector.shared().connectionState == ConnectionStateLoggedIn {
            let action = VoIPCallUserAction.init(action: startWithVideo ? .callWithVideo : .call, contact:contact!, callId: nil, completion: nil)
            VoIPCallStateManager.shared.processUserAction(action)
        } else {
            let title = BundleUtil.localizedString(forKey: "cannot_connect_title")
            let message = BundleUtil.localizedString(forKey: "cannot_connect_message")
            UIAlertTemplate.showAlert(owner: self, title: title, message: message) { (action) in
                self.extensionContext?.completeRequest(returningItems: [Any](), completionHandler: nil)
            }
        }
    }
    
    private func makeTelUrlForPhone(_ phoneNumber: String) -> URL {
        let urlString = "tel:\(phoneNumber.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlHostAllowed) ?? "")"
        return URL.init(string: urlString)!
    }
        
    private func linkNewContact(view: UIView) {
        if cnContact != nil {
            let actionSheet = UIAlertController.init(title: nil, message: nil, preferredStyle: .actionSheet)
            actionSheet.addAction(UIAlertAction.init(title: BundleUtil.localizedString(forKey: "unlink_contact"), style: .destructive, handler: { (action) in
                ContactStore.shared()?.unlinkContact(self.contact)
                self.updateView()
            }))
            actionSheet.addAction(UIAlertAction.init(title: BundleUtil.localizedString(forKey: "choose_new_contact"), style: .default, handler: { (action) in
                self.linkNewContactCheckAuthorization()
            }))
            actionSheet.addAction(UIAlertAction.init(title: BundleUtil.localizedString(forKey: "cancel"), style: .cancel, handler: { (action) in
                if let selectedRow = self.tableView!.indexPathForSelectedRow {
                    self.tableView.deselectRow(at: selectedRow, animated: true)
                }
            }))
            actionSheet.popoverPresentationController?.sourceRect = view.frame
            actionSheet.popoverPresentationController?.sourceView = view
            
            present(actionSheet, animated: true, completion: nil)
        } else {
            linkNewContactCheckAuthorization()
        }
    }
    
    private func linkNewContactCheckAuthorization() {
        if CNContactStore.authorizationStatus(for: .contacts) != .authorized {
            cnAddressBook.requestAccess(for: .contacts) { (granted, error) in
                if granted {
                    DispatchQueue.main.async {
                        self.linkNewContactPick()
                    }
                } else {
                    DispatchQueue.main.async {
                        let accessAlert = UIAlertController.init(title: BundleUtil.localizedString(forKey: "no_contacts_permission_title"), message: BundleUtil.localizedString(forKey: "no_contacts_permission_message"), preferredStyle: .alert)
                        if self.contact!.cnContactId != nil {
                            accessAlert.addAction(UIAlertAction.init(title: BundleUtil.localizedString(forKey: "unlink_contact"), style: .default, handler: { (action) in
                                ContactStore.shared()?.unlinkContact(self.contact!)
                                self.updateView()
                            }))
                        }
                        accessAlert.addAction(UIAlertAction.init(title: BundleUtil.localizedString(forKey: "ok"), style: .default, handler: nil))
                        self.present(accessAlert, animated: true, completion: nil)
                        if let selectedRow = self.tableView!.indexPathForSelectedRow {
                            self.tableView.deselectRow(at: selectedRow, animated: true)
                        }
                    }
                }
            }
        } else {
            linkNewContactPick()
        }
    }
    
    private func linkNewContactPick() {
        let picker = CNContactPickerViewController.init()
        picker.delegate = self
        picker.modalPresentationStyle = .formSheet
        present(picker, animated: true, completion: nil)
    }
    
    private func shouldHideCell(_ indexPath: IndexPath) -> Bool{
        switch indexPath.section {
        case 0:
            switch indexPath.row {
            case 2:
                if contact?.publicNickname == nil {
                    return true
                } else {
                    if contact?.publicNickname.count == 0 || contact?.publicNickname == contact?.identity {
                        return true
                    }
                }
                break
            case 3:
                if contact!.isGatewayId() {
                    return true
                }
                break
            default:
                break
            }
            break
        case 1:
            switch indexPath.row {
            case 1:
                if !UserSettings.shared().enableThreemaCall || is64Bit != 1 {
                    return true
                }
                break
            case 2:
                if canExportConversation == false {
                    return true
                }
                break
            case 3:
                if ScanIdentityController.canScan() == false {
                    return true
                }
                break
            case 4:
                if contact!.isGatewayId() || contact!.isEchoEcho() || UserSettings.shared().sendProfilePicture == SendProfilePictureNone || (UserSettings.shared().sendProfilePicture == SendProfilePictureContacts && !UserSettings.shared().profilePictureContactList.contains(where: {($0 as! String) == contact!.identity})) {
                    return true
                }
                break
            default:
                break
            }
            break
        default:
            break
        }
        return false
    }
    
    private func showWorkInfo(_ autoDismiss: Bool = true) {
        threemaTypeIcon.isHighlighted = false
        threemaTypeIcon.isSelected = false
        if showcase == nil {
            showcase = MaterialShowcase()
            showcase!.setTargetView(button: threemaTypeIcon)
            if LicenseStore.requiresLicenseKey() == false {
                showcase!.primaryText = BundleUtil.localizedString(forKey: "contact_threema_work_title")
                showcase!.secondaryText = BundleUtil.localizedString(forKey: "contact_threema_work_info")
                showcase!.backgroundPromptColor = Colors.workBlue()
            } else {
                showcase!.primaryText = BundleUtil.localizedString(forKey: "contact_threema_title")
                showcase!.secondaryText = BundleUtil.localizedString(forKey: "contact_threema_info")
                showcase!.backgroundPromptColor = Colors.green()
            }
            
            showcase!.backgroundPromptColorAlpha = 0.93
            showcase!.primaryTextSize = 24.0
            showcase!.secondaryTextSize = 20.0
            showcase!.primaryTextColor = Colors.white()
            showcase!.secondaryTextColor = Colors.white()
            showcase!.delegate = self
        }
        showcase!.show(completion: nil)
        if autoDismiss == true {
            DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: {
                if self.showcase != nil {
                    self.showcase!.completeShowcase()
                }
            })
        }

    }
    
    // MARK: IBAction
    
    @IBAction func shareButtonTapped(sender: UIButton) {
        let contactShareLink = String.init(format: "%@%@", THREEMA_ID_SHARE_LINK, contact!.identity)
        let contactShareText = "\(contact!.displayName!): \(contactShareLink)"
        let activityViewController = UIActivityViewController.init(activityItems: [contactShareText], applicationActivities: nil)
        if UIDevice.current.userInterfaceIdiom == .pad {
            activityViewController.popoverPresentationController?.sourceRect = sender.frame
            activityViewController.popoverPresentationController?.sourceView = view
        }
        present(activityViewController, animated: true, completion: nil)
    }
    
    @IBAction func scanQrCodeAction(sender: UIButton) {
        scanIdentityAction()
    }
    
    @IBAction func workInfoButtonTapped(sender: UIButton) {
        showWorkInfo(false)
    }
}
    
extension ContactDetailsViewController {
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        if !(contact!.isGatewayId()) && !contact!.isEchoEcho() && UserSettings.shared()?.sendProfilePicture == SendProfilePictureContacts {
            return 4
        }
        return 3
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 6
        case 1:
            return 5
        case 2:
            if !(contact!.isGatewayId()) && !contact!.isEchoEcho() && UserSettings.shared()?.sendProfilePicture == SendProfilePictureContacts {
                return 1
            } else {
                return 2
            }
        case 3:
            return 2
        default:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 2 && !contact!.isGatewayId() && !contact!.isEchoEcho() && UserSettings.shared().sendProfilePicture == SendProfilePictureContacts {
            if UserSettings.shared().profilePictureContactList.contains(where: {($0 as! String) == contact!.identity}) {
                return BundleUtil.localizedString(forKey: "contact_added_to_profilepicture_list")
            } else {
                return BundleUtil.localizedString(forKey: "contact_removed_from_profilepicture_list")
            }
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return shouldHideCell(indexPath) == true ? 0 : UITableView.automaticDimension
    }
            
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        super.tableView(tableView, willDisplay: cell, forRowAt: indexPath)
        
        cell.isHidden = shouldHideCell(indexPath)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            switch indexPath.row {
            case 0:
                let identityCell = tableView.dequeueReusableCell(withIdentifier: "IdentityCell")
                identityCell!.detailTextLabel?.text = contact?.identity
                identityCell!.detailTextLabel!.isAccessibilityElement = false
                let shareButton = identityCell?.accessoryView as! UIButton
                let shareImage: UIImage
                if #available(iOS 13.0, *) {
                    shareImage = shareButton.imageView!.image!.withTintColor(Colors.main())
                } else {
                    shareImage = shareButton.imageView!.image!.withTint(Colors.main())
                }
                shareButton.setImage(shareImage, for: .normal)
                return identityCell!
            case 1:
                let vlc = tableView.dequeueReusableCell(withIdentifier: "VerificationLevelCell") as! VerificationLevelCell
                vlc.contact = contact
                vlc.accessibilityTraits = .button
                return vlc
            case 2:
                let publicNicknameCell = tableView.dequeueReusableCell(withIdentifier: "PublicNicknameCell")
                publicNicknameCell!.detailTextLabel?.text = contact?.publicNickname
                return publicNicknameCell!
            case 3:
                let lcc = tableView.dequeueReusableCell(withIdentifier: "LinkedContactCell") as! LinkedContactCell
                lcc.accessibilityTraits = .button
                
                if cnContact != nil {
                    lcc.displayNameLabel.text = CNContactFormatter.string(from: cnContact!, style: .fullName)
                    if lcc.displayNameLabel.text == nil || lcc.displayNameLabel.text?.count == 0 {
                        if cnContact!.emailAddresses.count > 0 {
                            let first:CNLabeledValue = cnContact!.emailAddresses.first!
                            lcc.displayNameLabel.text = first.value as String
                        }
                    }
                } else {
                    lcc.displayNameLabel.text = BundleUtil.localizedString(forKey: "(none)")
                }
                return lcc
            case 4:
                let groupMembershipCell = tableView.dequeueReusableCell(withIdentifier: "GroupMembershipCell")
                groupMembershipCell?.textLabel?.text = BundleUtil.localizedString(forKey: "member_in_groups")
                groupMembershipCell?.detailTextLabel?.text = String.init(format: "%lu", contact?.groupConversations.count ?? 0)
                groupMembershipCell?.accessibilityTraits = .button
                return groupMembershipCell!
            case 5:
                let kfc = tableView.dequeueReusableCell(withIdentifier: "KeyFingerprintCell") as! KeyFingerprintCell
                kfc.fingerprintValueLabel.text = CryptoUtils.fingerprint(forPublicKey: contact?.publicKey)
                return kfc
            default:
                break
            }
        case 1:
            var cellIdentifier = ""
            switch indexPath.row {
            case 0:
                cellIdentifier = "SendMessageCell"
                break
            case 1:
                cellIdentifier = "ThreemaCallCell"
                break
            case 2:
                cellIdentifier = "ExportConversationCell"
                break
            case 3:
                cellIdentifier = "ScanIDCell"
                break
            case 4:
                cellIdentifier = "SendProfilePictureCell"
                break
            default:
                cellIdentifier = "SendMessageCell"
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier)
            cell?.accessibilityTraits = .button
            return cell!
        case 2:
            if !(contact!.isGatewayId()) && !contact!.isEchoEcho() && UserSettings.shared()?.sendProfilePicture == SendProfilePictureContacts {
                let profilePictureRecipientCell = tableView.dequeueReusableCell(withIdentifier: "ProfilePictureRecipientCell") as! ProfilePictureRecipientCell
                profilePictureRecipientCell.identity = contact?.identity
                profilePictureRecipientCell.delegate = self
                return profilePictureRecipientCell
            } else {
                switch indexPath.row {
                case 0:
                    let pushSettingCell = tableView.dequeueReusableCell(withIdentifier: "PushSettingCell")
                    pushSettingCell?.textLabel?.text = BundleUtil.localizedString(forKey: "pushSetting_title")
                    return pushSettingCell!
                case 1:
                    let bcc = tableView.dequeueReusableCell(withIdentifier: "BlockCell") as! BlockContactCell
                    bcc.identity = contact?.identity
                    return bcc
                default:
                    break
                }
            }
            break
        case 3:
            switch indexPath.row {
            case 0:
                let pushSettingCell = tableView.dequeueReusableCell(withIdentifier: "PushSettingCell")
                pushSettingCell?.textLabel?.text = BundleUtil.localizedString(forKey: "pushSetting_title")
                return pushSettingCell!
            case 1:
                let bcc = tableView.dequeueReusableCell(withIdentifier: "BlockCell") as! BlockContactCell
                bcc.identity = contact?.identity
                return bcc
            default:
                break
            }
            break
        default:
            break
        }
        return UITableViewCell()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        switch indexPath.section {
        case 0:
            if indexPath.row == 3 {
                linkNewContact(view: cell!)
            }
            else if indexPath.row == 4 {
                let vc = storyboard!.instantiateViewController(withIdentifier: "contactGroupMembershipViewController") as! ContactGroupMembershipViewController
                vc.groupContact = contact
                navigationController?.pushViewController(vc, animated: true)
            }
            break
        case 1:
            if cell?.reuseIdentifier == "SendMessageCell" {
                sendMessageAction()
            }
            else if cell?.reuseIdentifier == "ThreemaCallCell" {
                startThreemaCallAction()
            }
            else if cell?.reuseIdentifier == "ExportConversationCell" {
                tableView.deselectRow(at: indexPath, animated: true)
                conversationAction(sender: cell)
            }
            else if cell?.reuseIdentifier == "ScanIDCell" {
                scanIdentityAction()
            }
            else if cell?.reuseIdentifier == "SendProfilePictureCell" {
                startProfilePictureAction()
            }
            break
        default:
            break
        }
    }
    
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        if indexPath.section == 0 && indexPath.row == 1 {
            performSegue(withIdentifier: "VerificationSegue", sender: nil)
        }
    }
}

extension ContactDetailsViewController: ProfilePictureRecipientCellDelegate {
    func valueChanged(_ cell: ProfilePictureRecipientCell) {
        let indexSet: IndexSet = [1]
        tableView.beginUpdates()
        tableView.reloadSections(indexSet, with: .automatic)
        tableView.endUpdates()
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
}

extension ContactDetailsViewController: CNContactPickerDelegate {
    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        let statusNavigationBar = navigationController?.navigationBar as! StatusNavigationBar
        statusNavigationBar.showOrHideStatusView()
        ContactStore.shared()?.linkContact(self.contact, toCnContactId: contact.identifier)
        dismiss(animated: true, completion: nil)
        updateView()
    }
    
    func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
        dismiss(animated: true, completion: nil)
    }
    
    func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        if let selectedRow = self.tableView!.indexPathForSelectedRow {
            self.tableView.deselectRow(at: selectedRow, animated: true)
        }
        let statusNavigationBar = navigationController?.navigationBar as! StatusNavigationBar
        statusNavigationBar.showOrHideStatusView()
        dismiss(animated: true, completion: nil)
    }
}

extension ContactDetailsViewController: MaterialShowcaseDelegate {
    func showCaseWillDismiss(showcase: MaterialShowcase, didTapTarget: Bool) {
        UserSettings.shared()?.workInfoShown = true
    }
    
    func showCaseDidDismiss(showcase: MaterialShowcase, didTapTarget: Bool) {
    }
}
