//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2022 Threema GmbH
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
import UIKit

class ThreemaCallsSettingsViewController: ThemedTableViewController {
    
    @IBOutlet var enableThreemaCallsCell: UITableViewCell!
    @IBOutlet var alwaysRelayThreemaCallsCell: UITableViewCell!
    @IBOutlet var includeCallsInRecentsCell: UITableViewCell!
    @IBOutlet var enableVideoCell: UITableViewCell!
    
    @IBOutlet var enableThreemaCallSwitch: UISwitch!
    @IBOutlet var alwaysRelayThreemaCallsSwitch: UISwitch!
    @IBOutlet var includeCallsInRecentsSwitch: UISwitch!
    @IBOutlet var enableVideoSwitch: UISwitch!
    @IBOutlet var voIPSoundLabel: UILabel!
    @IBOutlet var voIPSoundValueLabel: UILabel!
    @IBOutlet var videoQualityCellTitleLabel: UILabel!
    @IBOutlet var videoQualityCellDetailLabel: UILabel!
    
    private let mdmSetup: MDMSetup
    private let settingsStore: SettingsStore
    private var settings: SettingsStore.Settings
    
    required init?(coder aDecoder: NSCoder) {
        self.mdmSetup = MDMSetup(setup: false)
        self.settingsStore = SettingsStore()
        self.settings = settingsStore.settings
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        title = BundleUtil.localizedString(forKey: "settings_threema_calls")
        setupCells()
        tableView.reloadData()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(incomingUpdate),
            name: NSNotification.Name(rawValue: kNotificationIncomingSettingsSynchronization),
            object: nil
        )
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidAppear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func incomingUpdate() {
        loadSettings()
        updateView()
        NotificationBannerHelper.newInfoToast(
            title: BundleUtil.localizedString(forKey: "incoming_settings_sync_title"),
            body: BundleUtil.localizedString(forKey: "incoming_settings_sync_message")
        )
    }
    
    private func loadSettings() {
        settings = settingsStore.settings
    }
    
    private func updateView() {
        setupCells()
        tableView.reloadData()
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        if is64Bit == 1 {
            if enableThreemaCallSwitch.isOn {
                return 5
            }
        }
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 4 {
            if enableVideoSwitch.isOn {
                return 2
            }
            return 1
        }
        
        return super.tableView(tableView, numberOfRowsInSection: section)
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 4:
            return BundleUtil.localizedString(forKey: "settings_threema_calls_video_section")
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if enableThreemaCallSwitch.isOn {
            switch section {
            case 2:
                if ThreemaApp.current == .onPrem {
                    return alwaysRelayThreemaCallsSwitch.isOn ? BundleUtil
                        .localizedString(forKey: "onprem_hide_voip_call_ip_on") : BundleUtil
                        .localizedString(forKey: "onprem_hide_voip_call_ip_off")
                }
                
                return alwaysRelayThreemaCallsSwitch.isOn ? BundleUtil
                    .localizedString(forKey: "hide_voip_call_ip_on") : BundleUtil
                    .localizedString(forKey: "hide_voip_call_ip_off")
            case 3:
                return includeCallsInRecentsSwitch.isOn ? BundleUtil
                    .localizedString(forKey: "voip_include_call_in_recents_on") : BundleUtil
                    .localizedString(forKey: "voip_include_call_in_recents_off")
            case 4:
                return enableVideoSwitch.isOn ? BundleUtil
                    .localizedString(forKey: "settings_threema_calls_video_quality_profile_footer") : nil
            default:
                return nil
            }
        }
        return nil
    }
    
    func attemptSave() {
        if ServerConnector.shared()?.isMultiDeviceActivated ?? false {
            let syncHelper = UISyncHelper(
                viewController: self,
                progressString: BundleUtil.localizedString(forKey: "syncing_settings")
            )
            
            syncHelper.execute(settings: settings)
                .catch { error in
                    DDLogWarn("Unable to sync call settings: \(error.localizedDescription)")
                }
                .finally {
                    self.updateView()
                }
        }
        else {
            settingsStore.save(settings)
            
            updateView()
        }
    }
}

private extension ThreemaCallsSettingsViewController {
    // MARK: Private functions
    
    private func setupCells() {
        if is64Bit == 1 {
            enableDisableCallCellForMDM(!mdmSetup.existsMdmKey(MDM_KEY_DISABLE_CALLS))
            enableDisableVideoCellForMDM(!mdmSetup.existsMdmKey(MDM_KEY_DISABLE_VIDEO_CALLS))
        }
        else {
            UserSettings.shared().enableThreemaCall = false
            enableThreemaCallSwitch.isOn = false
            enableThreemaCallsCell.isUserInteractionEnabled = false
            enableThreemaCallsCell.textLabel?.isEnabled = false
            enableThreemaCallSwitch.isEnabled = false
        }
        setupLabels()
        setupSwitches()
    }
    
    private func enableDisableCallCellForMDM(_ enable: Bool) {
        enableThreemaCallsCell.isUserInteractionEnabled = enable
        enableThreemaCallsCell.textLabel?.isEnabled = enable
        enableThreemaCallSwitch.isEnabled = enable
    }
    
    private func enableDisableVideoCellForMDM(_ enable: Bool) {
        enableVideoCell.isUserInteractionEnabled = enable
        enableVideoCell.textLabel?.isEnabled = enable
        enableVideoSwitch.isEnabled = enable
    }
    
    private func setupSwitches() {
        enableThreemaCallSwitch.isOn = UserSettings.shared().enableThreemaCall
        alwaysRelayThreemaCallsSwitch.isOn = UserSettings.shared().alwaysRelayCalls
        includeCallsInRecentsSwitch.isOn = UserSettings.shared().includeCallsInRecents
        enableVideoSwitch.isOn = UserSettings.shared().enableVideoCall
    }
    
    private func setupLabels() {
        enableThreemaCallsCell.textLabel?.text = BundleUtil
            .localizedString(forKey: "settings_threema_calls_enable_calls")
        alwaysRelayThreemaCallsCell.textLabel?.text = BundleUtil
            .localizedString(forKey: "settings_threema_calls_always_relay_calls")
        includeCallsInRecentsCell.textLabel?.text = BundleUtil.localizedString(forKey: "settings_threema_calls_callkit")
        enableVideoCell.textLabel?.text = BundleUtil.localizedString(forKey: "settings_threema_calls_allow_video_calls")
        videoQualityCellTitleLabel?.text = BundleUtil
            .localizedString(forKey: "settings_threema_calls_video_quality_profile")
        videoQualityCellDetailLabel?.text = CallsignalingProtocol.currentThreemaVideoCallQualitySettingTitle()
        voIPSoundLabel?.text = BundleUtil.localizedString(forKey: "settings_threema_calls_call_sound")
        let voIPSoundName = "sound_\(UserSettings.shared().voIPSound!)"
        voIPSoundValueLabel?.text = BundleUtil.localizedString(forKey: voIPSoundName)
    }
    
    // MARK: IBActions
    
    @IBAction func enableThreemaCallSwitchChanged(sender: UISwitch) {
        settings.enableThreemaCall = sender.isOn
        
        attemptSave()
    }
    
    @IBAction func alwaysRelayCallsSwitchChanged(sender: UISwitch) {
        settings.alwaysRelayCalls = sender.isOn
        
        attemptSave()
    }
    
    @IBAction func includeCallsInRecentsSwitchChanged(sender: UISwitch) {
        UserSettings.shared().includeCallsInRecents = sender.isOn
        setupSwitches()
        tableView.reloadData()
    }
    
    @IBAction func enableVideoCallSwitchChanged(sender: UISwitch) {
        UserSettings.shared().enableVideoCall = sender.isOn
        setupSwitches()
        tableView.reloadData()
    }
}
