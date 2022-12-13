//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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
import PromiseKit
import ThreemaFramework

class PrivacySettingsViewController: ThemedTableViewController {
    private let mdmSetup: MDMSetup
    private let userSettings: UserSettings
    private let settingsStore: SettingsStore
    private var settings: SettingsStore.Settings
    
    @IBOutlet var syncContactsSwitch: UISwitch!
    @IBOutlet var blockUnknownSwitch: UISwitch!
    @IBOutlet var poiSwitch: UISwitch!
    @IBOutlet var hidePrivateChatsSwitch: UISwitch!
    
    @IBOutlet var syncContactsCell: UITableViewCell!
    @IBOutlet var blockUnknownCell: UITableViewCell!
    @IBOutlet var readReceiptsCell: UITableViewCell!
    @IBOutlet var typingIndicatorsCell: UITableViewCell!
    
    @IBOutlet var syncContactsLabel: UILabel!
    @IBOutlet var blockUnknownLabel: UILabel!
    @IBOutlet var hidePrivateChatsLabel: UILabel!
    
    private lazy var lockScreenWrapper = LockScreen(isLockScreenController: true)

    required init?(coder: NSCoder) {
        self.mdmSetup = MDMSetup(setup: false)
        self.userSettings = UserSettings.shared()
        self.settingsStore = SettingsStore()
        self.settings = settingsStore.settings
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        hidePrivateChatsLabel.text = BundleUtil.localizedString(forKey: "hide_private_toggle")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        resetSwitches()
        disableCellsForMDM()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(incomingUpdate),
            name: NSNotification.Name(rawValue: kNotificationIncomingSettingsSynchronization),
            object: nil
        )
        
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = UITableView.automaticDimension
        
        readReceiptsCell.textLabel?.text = BundleUtil.localizedString(forKey: "send_readReceipts")
        typingIndicatorsCell.textLabel?.text = BundleUtil.localizedString(forKey: "send_typingIndicators")

        tableView.reloadData()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidAppear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func incomingUpdate() {
        resetSwitches()
        disableCellsForMDM()
        NotificationBannerHelper.newInfoToast(
            title: BundleUtil.localizedString(forKey: "incoming_settings_sync_title"),
            body: BundleUtil.localizedString(forKey: "incoming_settings_sync_message")
        )
    }
    
    override var shouldAutorotate: Bool {
        true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }
    
    func toggleBackButton() {
        if navigationController != nil {
            navigationController!.navigationBar.isUserInteractionEnabled = !navigationController!.navigationBar
                .isUserInteractionEnabled
            if navigationController!.interactivePopGestureRecognizer != nil {
                navigationController!.interactivePopGestureRecognizer!.isEnabled = !navigationController!
                    .interactivePopGestureRecognizer!.isEnabled
            }
        }
    }
    
    func attemptSave() -> Promise<Void> {
        if ServerConnector.shared()?.isMultiDeviceActivated ?? false {
            let syncHelper = UISyncHelper(
                viewController: self,
                progressString: BundleUtil.localizedString(forKey: "syncing_settings"),
                navigationController: navigationController
            )
            
            return syncHelper.execute(settings: settings)
        }
        else {
            if !settings.syncContacts, syncContactsSwitch.isOn {
                ContactStore.shared()
                    .synchronizeAddressBook(
                        forceFullSync: true,
                        ignoreMinimumInterval: true,
                        onCompletion: nil,
                        onError: nil
                    )
            }
            
            settingsStore.save(settings)
            resetSwitches()
            disableCellsForMDM()

            return Promise()
        }
    }
    
    @objc func resetSwitches() {
        settings = settingsStore.settings
        
        syncContactsSwitch.isOn = settings.syncContacts
        blockUnknownSwitch.isOn = settings.blockUnknown
        
        if UserSettings.shared().sendReadReceipts {
            readReceiptsCell.detailTextLabel?.text = BundleUtil.localizedString(forKey: "send")
        }
        else {
            readReceiptsCell.detailTextLabel?.text = BundleUtil.localizedString(forKey: "dont_send")
        }
        
        if UserSettings.shared().sendTypingIndicator {
            typingIndicatorsCell.detailTextLabel?.text = BundleUtil.localizedString(forKey: "send")
        }
        else {
            typingIndicatorsCell.detailTextLabel?.text = BundleUtil.localizedString(forKey: "dont_send")
        }
       
        poiSwitch.isOn = userSettings.enablePoi

        hidePrivateChatsSwitch.isOn = userSettings.hidePrivateChats
        hidePrivateChatsSwitch.isEnabled = KKPasscodeLock.shared().isPasscodeRequired()

        tableView.reloadData()
    }
    
    @IBAction func syncContactsChanged(_ sender: Any) {
        settings.syncContacts = syncContactsSwitch.isOn

        let currentIsOn = syncContactsSwitch.isOn

        attemptSave()
            .done {
                // Reset contact import status only if setting is successfully synced and setting contact sync is off
                if !self.syncContactsSwitch.isOn, self.userSettings.syncContacts == currentIsOn {
                    ContactStore.shared().resetImportedStatus()
                }
            }
            .catch { error in
                DDLogWarn("Unable to sync privacy setting sync contacts: \(error.localizedDescription)")
            }
            .finally {
                self.resetSwitches()
                self.disableCellsForMDM()
            }
    }
    
    @IBAction func blockUnknownChanged(_ sender: Any) {
        settings.blockUnknown = blockUnknownSwitch.isOn
        
        attemptSave()
            .catch { error in
                DDLogWarn("Unable to sync privacy setting block unknown: \(error.localizedDescription)")
            }
            .finally {
                self.resetSwitches()
                self.disableCellsForMDM()
            }
    }
    
    @IBAction func poiSwitchChanged(_ sender: Any) {
        userSettings.enablePoi = poiSwitch.isOn
    }
    
    @IBAction func hidePrivacyChatsSwitchChanged(_ sender: Any) {
        if userSettings.hidePrivateChats {
            lockScreenWrapper.presentLockScreenView(
                viewController: self,
                enteredCorrectly: {
                    self.userSettings.hidePrivateChats = false
                    self.hidePrivateChatsSwitch.isOn = false
                    NotificationCenter.default.post(
                        name: Notification.Name(kNotificationChangedHidePrivateChat),
                        object: nil,
                        userInfo: nil
                    )
                }
            )
            hidePrivateChatsSwitch.isOn = true
        }
        else {
            userSettings.hidePrivateChats = true
            NotificationCenter.default.post(
                name: Notification.Name(kNotificationChangedHidePrivateChat),
                object: nil,
                userInfo: nil
            )
        }
    }
    
    func disableCellsForMDM() {
        let isBlockUnknownManaged = mdmSetup.existsMdmKey(MDM_KEY_BLOCK_UNKNOWN)
        blockUnknownCell.isUserInteractionEnabled = !isBlockUnknownManaged
        blockUnknownLabel.isEnabled = !isBlockUnknownManaged
        blockUnknownSwitch.isEnabled = !isBlockUnknownManaged
        
        let isContactSyncManaged = mdmSetup.existsMdmKey(MDM_KEY_CONTACT_SYNC)
        syncContactsCell.isUserInteractionEnabled = !isContactSyncManaged
        syncContactsLabel.isEnabled = !isContactSyncManaged
        syncContactsSwitch.isEnabled = !isContactSyncManaged
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 0 {
            var footer = ""
            if settings.blockUnknown {
                footer = BundleUtil.localizedString(forKey: "block_unknown_on")
            }
            else {
                footer = BundleUtil.localizedString(forKey: "block_unknown_off")
            }
            
            if mdmSetup.existsMdmKey(MDM_KEY_BLOCK_UNKNOWN) || mdmSetup.existsMdmKey(MDM_KEY_CONTACT_SYNC) {
                footer = footer + "\n\n" + BundleUtil.localizedString(forKey: "disabled_by_device_policy")
            }
            return footer
        }
        else if section == 1 {
            return BundleUtil.localizedString(forKey: "privacy_footer")
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if indexPath == IndexPath(row: 0, section: 1) {
            navigationController?.pushViewController(
                ReadReceiptsSettingsViewController(style: .grouped),
                animated: true
            )
        }
        else if indexPath == IndexPath(row: 1, section: 1) {
            navigationController?.pushViewController(
                TypingIndicatorsSettingsViewController(style: .grouped),
                animated: true
            )
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
