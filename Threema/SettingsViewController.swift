//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2021 Threema GmbH
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

class SettingsViewController: ThemedTableViewController {
                    
    @IBOutlet weak var privacyCell: UITableViewCell!
    @IBOutlet weak var appearanceCell: UITableViewCell!
    @IBOutlet weak var notificationCell: UITableViewCell!
    @IBOutlet weak var chatCell: UITableViewCell!
    @IBOutlet weak var mediaCell: UITableViewCell!
    @IBOutlet weak var storageManagementCell: UITableViewCell!
    @IBOutlet weak var passcodeLockCell: UITableViewCell!
    @IBOutlet weak var threemaCallsCell: UITableViewCell!
    @IBOutlet weak var threemaWebCell: UITableViewCell!
    @IBOutlet weak var networkStatusCell: UITableViewCell!
    @IBOutlet weak var versionCell: UITableViewCell!
    @IBOutlet weak var usernameCell: UITableViewCell!
    @IBOutlet weak var inviteAFriendCell: UITableViewCell!
    @IBOutlet weak var threemaChannelCell: UITableViewCell!
    @IBOutlet weak var threemaWorkCell: UITableViewCell!
    @IBOutlet weak var supportCell: UITableViewCell!
    @IBOutlet weak var privacyPolicyCell: UITableViewCell!
    @IBOutlet weak var licenseCell: UITableViewCell!
    @IBOutlet weak var advancedCell: UITableViewCell!
    
    @IBOutlet weak var devModeCell: UITableViewCell!
    
    @IBOutlet weak var usernameCellLabel: UILabel!
    @IBOutlet weak var userNameCellDetailLabel: UILabel!
    
    
    private var inviteController: InviteController?
    private var observing: Bool = false
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .all
        }
        return .allButUpsideDown
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        var version = BundleUtil.mainBundle()!.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        if let suffix = BundleUtil.mainBundle()!.object(forInfoDictionaryKey: "ThreemaVersionSuffix") as? String {
            version = version.appending(suffix)
            let build = BundleUtil.mainBundle()!.object(forInfoDictionaryKey: kCFBundleVersionKey as String)
            versionCell.detailTextLabel?.text = "\(version) (\(build!))"
            if let versionCopyLabel = versionCell.detailTextLabel as? CopyLabel {
                versionCopyLabel.textForCopying = "\(version)b\(build ?? "0")"
            }
            
            userNameCellDetailLabel?.text = LicenseStore.shared().licenseUsername
            NotificationCenter.default.addObserver(self, selector: #selector(colorThemeChanged), name: NSNotification.Name(rawValue: kNotificationColorThemeChanged) , object: nil)
            BrandingUtils.updateTitleLogo(of: self.navigationItem, navigationController: self.navigationController)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateTitleLabels()
        
        updateConnectionStatus()
        updatePasscodeLock()
        updateThreemaWeb()
        
        registerObserver()
        
        if #available(iOS 11.0, *) {
            self.navigationItem.largeTitleDisplayMode = UINavigationItem.LargeTitleDisplayMode(rawValue: (UserSettings.shared()?.largeTitleDisplayMode)!)!
        }
        
        // iOS fix where the logo is moved to the right sometimes
        if navigationController!.navigationBar.frame.size.height == 44.0 && LicenseStore.requiresLicenseKey() {
            BrandingUtils.updateTitleLogo(of: navigationItem, navigationController: navigationController)
        }
        else if navigationController!.navigationBar.frame.size.height == 44.0 && LicenseStore.requiresLicenseKey() == false && navigationItem.titleView != nil {
            BrandingUtils.updateTitleLogo(of: navigationItem, navigationController: navigationController)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unregisterObserver()
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "ThreemaWorkSegue" {
            let appUrl = URL.init(string: "threemawork://app")
            if UIApplication.shared.canOpenURL(appUrl!) {
                UIApplication.shared.open(appUrl!, options: [:], completionHandler: nil)
                return false
            }
        }
        return true
    }
        
    @objc func colorThemeChanged(notification: Notification) {
        BrandingUtils.updateTitleLogo(of: self.navigationItem, navigationController: self.navigationController)
        if #available(iOS 11.0, *) {
            // set large title color for settingsviewcontroller; it will not automaticly change the color when set new appearance
            self.navigationController?.navigationBar.largeTitleTextAttributes = [NSAttributedString.Key.foregroundColor: Colors.fontNormal()!]
        }
    }
 
}

extension SettingsViewController {
    // MARK: private functions
    
    private func registerObserver() {
        if observing == false {
            ServerConnector.shared()?.addObserver(self, forKeyPath: "connectionState", options: [], context: nil)
            WCSessionManager.shared.addObserver(self, forKeyPath: "running", options: [], context: nil)
            observing = true
        }
    }
    
    private func unregisterObserver() {
        if observing == true {
            ServerConnector.shared()?.removeObserver(self, forKeyPath: "connectionState")
            WCSessionManager.shared.removeObserver(self, forKeyPath: "running")
            observing = false
        }
    }
    
    private func updateTitleLabels() {
        
        let suffix = Colors.getTheme() == ColorThemeDark || Colors.getTheme() == ColorThemeDarkWork ? "Dark" : "Light"
        
        privacyCell.textLabel?.text = BundleUtil.localizedString(forKey: "settings_privacy")
        privacyCell.imageView?.image = BundleUtil.imageNamed("Privacy\(suffix)")
        
        appearanceCell.textLabel?.text = BundleUtil.localizedString(forKey: "settings_appearance")
        appearanceCell.imageView?.image = BundleUtil.imageNamed("Appearance\(suffix)")
        
        notificationCell.textLabel?.text = BundleUtil.localizedString(forKey: "settings_notification")
        notificationCell.imageView?.image = BundleUtil.imageNamed("Notifications\(suffix)")
        
        chatCell.textLabel?.text = BundleUtil.localizedString(forKey: "settings_chat")
        chatCell.imageView?.image = BundleUtil.imageNamed("Chat\(suffix)")
        
        mediaCell.textLabel?.text = BundleUtil.localizedString(forKey: "settings_media")
        mediaCell.imageView?.image = BundleUtil.imageNamed("Media\(suffix)")
        
        storageManagementCell.textLabel?.text = BundleUtil.localizedString(forKey: "settings_storage_management")
        storageManagementCell.imageView?.image = BundleUtil.imageNamed("StorageManagement\(suffix)")
        
        devModeCell.textLabel?.text = BundleUtil.localizedString(forKey: "settings_dev_mode")
        devModeCell.imageView?.image = BundleUtil.imageNamed("DevMode\(suffix)")
        
        passcodeLockCell.textLabel?.text = BundleUtil.localizedString(forKey: "settings_passcode_lock")
        passcodeLockCell.imageView?.image = BundleUtil.imageNamed("PasscodeLock\(suffix)")
        
        threemaCallsCell.textLabel?.text = BundleUtil.localizedString(forKey: "settings_threema_calls")
        threemaCallsCell.imageView?.image = BundleUtil.imageNamed("ThreemaCallsSettings\(suffix)")
        
        threemaWebCell.textLabel?.text = BundleUtil.localizedString(forKey: "settings_threema_web")
        threemaWebCell.imageView?.image = BundleUtil.imageNamed("ThreemaWeb\(suffix)")
        
        networkStatusCell.textLabel?.text = BundleUtil.localizedString(forKey: "settings_network_status")
        
        versionCell.textLabel?.text = BundleUtil.localizedString(forKey: "settings_version")
        
        usernameCellLabel.text = BundleUtil.localizedString(forKey: "settings_license_username")
        
        inviteAFriendCell.textLabel?.text = BundleUtil.localizedString(forKey: "settings_invite_a_friend")
        inviteAFriendCell.imageView?.image = BundleUtil.imageNamed("InviteAFriend\(suffix)")
        
        threemaChannelCell.textLabel?.text = BundleUtil.localizedString(forKey: "settings_threema_channel")
        threemaChannelCell.imageView?.image = BundleUtil.imageNamed("ThreemaChannel\(suffix)")
        
        threemaWorkCell.textLabel?.text = BundleUtil.localizedString(forKey: "settings_threema_work")
        threemaWorkCell.imageView?.image = BundleUtil.imageNamed("ThreemaWorkSettings\(suffix)")
        
        supportCell.textLabel?.text = BundleUtil.localizedString(forKey: "settings_support")
        supportCell.imageView?.image = BundleUtil.imageNamed("Support\(suffix)")
        
        privacyPolicyCell.textLabel?.text = BundleUtil.localizedString(forKey: "settings_privacy_policy")
        privacyPolicyCell.imageView?.image = BundleUtil.imageNamed("PrivacyPolicy\(suffix)")
        
        licenseCell.textLabel?.text = BundleUtil.localizedString(forKey: "settings_license")
        licenseCell.imageView?.image = BundleUtil.imageNamed("License\(suffix)")
        
        advancedCell.textLabel?.text = BundleUtil.localizedString(forKey: "settings_advanced")
        advancedCell.imageView?.image = BundleUtil.imageNamed("Advanced\(suffix)")
    }
    
    private func updateConnectionStatus() {
        let stateName = ServerConnector.shared().name(for: ServerConnector.shared().connectionState)
        let locKey = "status_\(stateName!)"
        
        var statusText = BundleUtil.localizedString(forKey: locKey)
        if ServerConnector.shared()?.isIPv6Connection == true {
            statusText = statusText.appending(" (IPv6)")
        }
        if ServerConnector.shared()?.isProxyConnection == true {
            statusText = statusText.appending(" (Proxy)")
        }
        
        networkStatusCell.detailTextLabel?.text = statusText
    }
    
    private func updatePasscodeLock() {
        if KKPasscodeLock.shared().isPasscodeRequired() == true {
            passcodeLockCell.detailTextLabel!.text = BundleUtil.localizedString(forKey: "On")
        } else {
            passcodeLockCell.detailTextLabel!.text = BundleUtil.localizedString(forKey: "Off")
        }
    }
    
    private func updateThreemaWeb() {
        if UserSettings.shared().threemaWeb == true {
            if WCSessionManager.shared.isRunningWCSession() == true {
                threemaWebCell.detailTextLabel?.text = BundleUtil.localizedString(forKey: "status_loggedin")
            } else {
                threemaWebCell.detailTextLabel?.text = BundleUtil.localizedString(forKey: "On")
            }
        } else {
            threemaWebCell.detailTextLabel?.text = BundleUtil.localizedString(forKey: "Off")
        }
    }
}

extension SettingsViewController {
    // MARK: DB observer
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if  object as? ServerConnector == ServerConnector.shared() && keyPath == "connectionState" {
            DispatchQueue.main.async {
                self.updateConnectionStatus()
            }
        }
        else if object as? ServerConnector == ServerConnector.shared() && keyPath == "running" {
            DispatchQueue.main.async {
                self.updateThreemaWeb()
            }
        }
    }
}

extension SettingsViewController {
    // MARK: Table view delegate
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if #available(iOS 11.0, *) {
            if section == 0 {
                return 38.0
            }
        }
        
        if LicenseStore.requiresLicenseKey() {
            if section == 3 {
                return 0.0
            }
        }
                
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if LicenseStore.requiresLicenseKey() {
            if section == 3 {
                return 0.0
            }
        }
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if section == 0 {
            #if !DEBUG
                return super.tableView(tableView, numberOfRowsInSection: section) - 1
            #endif
        }
        
        // hide Threema Channel for work
        if LicenseStore.requiresLicenseKey() {
            if section == 2 {
                return 3
            }
            if section == 3 {
                return 0
            }
        } else {
            if section == 2 {
                return 2
            }
        }
        
        return super.tableView(tableView, numberOfRowsInSection: section)
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if LicenseStore.requiresLicenseKey() {
            if indexPath.section == 3 {
                return 0.0
            }
        }
        
        return super.tableView(tableView, heightForRowAt: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 && indexPath.row == 6 {
            let vc = KKPasscodeSettingsViewController.init(style: .grouped)
            vc.delegate = self
            navigationController?.pushViewController(vc, animated: true)
        }
        else if indexPath.section == 3 && indexPath.row == 0 {
            inviteController = InviteController.init()
            inviteController!.parentViewController = self
            inviteController!.shareViewController = self
            inviteController!.actionSheetViewController = self
            inviteController!.rect = tableView.rectForRow(at: indexPath)
            inviteController!.invite()
        }
        else if indexPath.section == 3 && indexPath.row == 1 {
            let addThreemaChannelController = AddThreemaChannelController.init()
            addThreemaChannelController.parentViewController = self
            addThreemaChannelController.addThreemaChannel()
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension SettingsViewController {
    // MARK: UIScrollViewDelegate
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if LicenseStore.requiresLicenseKey() == false {
            if navigationController!.navigationBar.frame.size.height < 60.0 && navigationItem.titleView != nil {
                navigationItem.titleView = nil
                navigationItem.title = BundleUtil.localizedString(forKey: "settings")
            }
            else if navigationController!.navigationBar.frame.size.height >= 59.5 && navigationItem.titleView == nil {
                BrandingUtils.updateTitleLogo(of: navigationItem, navigationController: navigationController)
            }
        }
    }
}

extension SettingsViewController: KKPasscodeSettingsViewControllerDelegate {
    func didSettingsChanged(_ viewController: KKPasscodeSettingsViewController!) {
        updatePasscodeLock()
    }
}
