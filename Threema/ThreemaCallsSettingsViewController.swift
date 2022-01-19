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

import UIKit

class ThreemaCallsSettingsViewController: ThemedTableViewController {

    @IBOutlet weak var enableThreemaCallsCell: UITableViewCell!
    @IBOutlet weak var alwaysRelayThreemaCallsCell: UITableViewCell!
    @IBOutlet weak var enableCallKitCell: UITableViewCell!
    @IBOutlet weak var enableVideoCell: UITableViewCell!
    
    @IBOutlet weak var enableThreemaCallSwitch: UISwitch!
    @IBOutlet weak var alwaysRelayThreemaCallsSwitch: UISwitch!
    @IBOutlet weak var enableCallKitSwitch: UISwitch!
    @IBOutlet weak var enableVideoSwitch: UISwitch!
    @IBOutlet weak var videoQualityCellTitleLabel: UILabel!
    @IBOutlet weak var videoQualityCellDetailLabel: UILabel!
    
    let mdmSetup: MDMSetup
    
    required init?(coder aDecoder: NSCoder) {
        self.mdmSetup = MDMSetup(setup: false)
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.title = BundleUtil.localizedString(forKey: "settings_threema_calls")
        self.setupCells()
        self.tableView.reloadData()
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        if is64Bit == 1 {
            if enableThreemaCallSwitch.isOn {
                return 4
            }
        }
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 3 {
            if enableVideoSwitch.isOn {
                return 2
            }
            return 1
        }
        
        return super.tableView(tableView, numberOfRowsInSection: section)
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 3:
            return BundleUtil.localizedString(forKey: "settings_threema_calls_video_section")
        default:
            return nil
        }
    }
        
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if enableThreemaCallSwitch.isOn {
            switch section {
            case 1:
                return alwaysRelayThreemaCallsSwitch.isOn ? BundleUtil.localizedString(forKey: "hide_voip_call_ip_on") : BundleUtil.localizedString(forKey: "hide_voip_call_ip_off")
            case 2:
                return enableCallKitSwitch.isOn ? BundleUtil.localizedString(forKey: "voip_callkit_on") : BundleUtil.localizedString(forKey: "voip_callkit_off")
            case 3:
                return enableVideoSwitch.isOn ? BundleUtil.localizedString(forKey: "settings_threema_calls_video_quality_profile_footer") : nil
            default:
                return nil
            }
        }
        return nil
    }
}

private extension ThreemaCallsSettingsViewController {
    // MARK: Private functions
    
    private func setupCells() {
        if is64Bit == 1 {
            enableDisableCallCellForMDM(!mdmSetup.existsMdmKey(MDM_KEY_DISABLE_CALLS))
            enableDisableVideoCellForMDM(!mdmSetup.existsMdmKey(MDM_KEY_DISABLE_VIDEO_CALLS))
        } else {
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
    
    private func disableCallKitForCN() {
        enableCallKitCell.isUserInteractionEnabled = false
        enableCallKitCell.textLabel?.isEnabled = false
        enableCallKitSwitch.isEnabled = false
        enableCallKitSwitch.isOn = false
        UserSettings.shared().enableCallKit = false
    }
    
    private func setupSwitches() {
        self.enableThreemaCallSwitch.isOn = UserSettings.shared().enableThreemaCall
        self.alwaysRelayThreemaCallsSwitch.isOn = UserSettings.shared().alwaysRelayCalls
        self.enableCallKitSwitch.isOn = UserSettings.shared().enableCallKit
        self.enableVideoSwitch.isOn = UserSettings.shared().enableVideoCall
        
        if is64Bit == 1 {
            if !mdmSetup.disableCalls() {
                if (Locale.current as NSLocale).object(forKey: .countryCode) as? String == "CN" {
                    disableCallKitForCN()
                }
            }
        }
    }
    
    private func setupLabels() {
        enableThreemaCallsCell.textLabel?.text = BundleUtil.localizedString(forKey: "settings_threema_calls_enable_calls")
        alwaysRelayThreemaCallsCell.textLabel?.text = BundleUtil.localizedString(forKey: "settings_threema_calls_always_relay_calls")
        enableCallKitCell.textLabel?.text = BundleUtil.localizedString(forKey: "settings_threema_calls_callkit")
        enableVideoCell.textLabel?.text = BundleUtil.localizedString(forKey: "settings_threema_calls_allow_video_calls")
        videoQualityCellTitleLabel?.text = BundleUtil.localizedString(forKey: "settings_threema_calls_video_quality_profile")
        videoQualityCellDetailLabel?.text = CallsignalingProtocol.currentThreemaVideoCallQualitySettingTitle()
    }
    
    // MARK IBActions
        
    @IBAction func enableThreemaCallSwitchChanged(sender: UISwitch) {
        UserSettings.shared().enableThreemaCall = sender.isOn
        setupSwitches()
        tableView.reloadData()
    }
    
    @IBAction func alwaysRelayCallsSwitchChanged(sender: UISwitch) {
        UserSettings.shared().alwaysRelayCalls = sender.isOn
        setupSwitches()
        tableView.reloadData()
    }
    
    @IBAction func enableCallKitSwitchChanged(sender: UISwitch) {
        UserSettings.shared().enableCallKit = sender.isOn
        setupSwitches()
        tableView.reloadData()
    }
    
    @IBAction func enableVideoCallSwitchChanged(sender: UISwitch) {
        UserSettings.shared().enableVideoCall = sender.isOn
        setupSwitches()
        tableView.reloadData()
    }
}
