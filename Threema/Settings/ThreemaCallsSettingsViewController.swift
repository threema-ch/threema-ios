//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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
    private var settingsStore: SettingsStoreProtocol
    
    required init?(coder aDecoder: NSCoder) {
        self.mdmSetup = MDMSetup(setup: false)
        self.settingsStore = BusinessInjector().settingsStore
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
        updateView()
    }
    
    private func updateView() {
        setupCells()
        tableView.reloadData()
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        if enableThreemaCallSwitch.isOn {
            return 5
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
                        .localizedString(forKey: "settings_threema_calls_onprem_hide_voip_call_ip_footer_on") :
                        BundleUtil
                        .localizedString(forKey: "settings_threema_calls_onprem_hide_voip_call_ip_footer_off")
                }
                
                return alwaysRelayThreemaCallsSwitch.isOn ? BundleUtil
                    .localizedString(forKey: "settings_threema_calls_hide_voip_call_ip_footer_on") : BundleUtil
                    .localizedString(forKey: "settings_threema_calls_hide_voip_call_ip_footer_off")
            case 3:
                return includeCallsInRecentsSwitch.isOn ? BundleUtil
                    .localizedString(forKey: "settings_threema_voip_include_call_in_recents_footer_on") : BundleUtil
                    .localizedString(forKey: "settings_threema_voip_include_call_in_recents_footer_off")
            case 4:
                return enableVideoSwitch.isOn ? BundleUtil
                    .localizedString(forKey: "settings_threema_calls_video_quality_profile_footer") : nil
            default:
                return nil
            }
        }
        else if !ThreemaEnvironment.supportsCallKit() {
            return BundleUtil
                .localizedString(forKey: "settings_threema_voip_no_callkit_in_china_footer")
        }
        return nil
    }
}

extension ThreemaCallsSettingsViewController {
    // MARK: Private functions
    
    private func setupCells() {
        enableDisableCallCellForMDM(!mdmSetup.existsMdmKey(MDM_KEY_DISABLE_CALLS))
        enableDisableVideoCellForMDM(!mdmSetup.existsMdmKey(MDM_KEY_DISABLE_VIDEO_CALLS))
        setupLabels()
        setupSwitches()
    }
    
    private func enableDisableCallCellForMDM(_ enable: Bool) {
        var shouldEnable = enable
        if !ThreemaEnvironment.supportsCallKit() {
            shouldEnable = false
        }
        
        enableThreemaCallsCell.isUserInteractionEnabled = shouldEnable
        enableThreemaCallsCell.textLabel?.isEnabled = shouldEnable
        enableThreemaCallSwitch.isEnabled = shouldEnable
    }
    
    private func enableDisableVideoCellForMDM(_ enable: Bool) {
        enableVideoCell.isUserInteractionEnabled = enable
        enableVideoCell.textLabel?.isEnabled = enable
        enableVideoSwitch.isEnabled = enable
    }
    
    private func setupSwitches() {
        enableThreemaCallSwitch.isOn = settingsStore.enableThreemaCall
        alwaysRelayThreemaCallsSwitch.isOn = settingsStore.alwaysRelayCalls
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
    
    @IBAction private func enableThreemaCallSwitchChanged(sender: UISwitch) {
        settingsStore.enableThreemaCall = sender.isOn
        updateView()
    }
    
    @IBAction private func alwaysRelayCallsSwitchChanged(sender: UISwitch) {
        settingsStore.alwaysRelayCalls = sender.isOn
    }
    
    @IBAction private func includeCallsInRecentsSwitchChanged(sender: UISwitch) {
        UserSettings.shared().includeCallsInRecents = sender.isOn
        setupSwitches()
        tableView.reloadData()
    }
    
    @IBAction private func enableVideoCallSwitchChanged(sender: UISwitch) {
        UserSettings.shared().enableVideoCall = sender.isOn
        setupSwitches()
        tableView.reloadData()
    }
}
