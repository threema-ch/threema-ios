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
import Foundation
import Intents
import ThreemaFramework
class DevModeViewController: ThemedTableViewController {
    
    @IBOutlet var newChatViewLabel: UILabel!
    @IBOutlet var newChatViewSwitch: UISwitch!
    @IBOutlet var allowSeveralLinkedDevicesLabel: UILabel!

    @IBOutlet var flippedTableViewSwitch: UISwitch!
    @IBOutlet var initialScrollPositionAlt1Switch: UISwitch!
    @IBOutlet var donateInteractionsSwitch: UISwitch!
    @IBOutlet var styleKitDebugViewLabel: UILabel!
    @IBOutlet var idColorsDebugViewLabel: UILabel!
    @IBOutlet var allowSeveralLinkedDevicesSwitch: UISwitch!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = BundleUtil.localizedString(forKey: "settings_dev_mode")
        navigationItem.largeTitleDisplayMode = .never
        
        configureLabels()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateNewChatViewSwitch()
    }

    // MARK: - Configure
    
    private func configureLabels() {
        newChatViewLabel.text = BundleUtil.localizedString(forKey: "settings_devmode_new_chat_view")
        styleKitDebugViewLabel.text = BundleUtil.localizedString(forKey: "settings_devmode_stylekit_debug_view")
        idColorsDebugViewLabel.text = BundleUtil.localizedString(forKey: "settings_devmode_id_colors_debug_view")
        allowSeveralLinkedDevicesLabel.text = "Allow several linked devices"
    }
    
    // MARK: - Update
    
    private func updateNewChatViewSwitch() {
        newChatViewSwitch.isOn = UserSettings.shared().newChatViewActive
        donateInteractionsSwitch.isOn = UserSettings.shared().donateInteractions
        allowSeveralLinkedDevicesSwitch.isOn = UserSettings.shared().allowSeveralLinkedDevices
        initialScrollPositionAlt1Switch.isOn = UserSettings.shared().initialScrollPositionAlt1
        flippedTableViewSwitch.isOn = UserSettings.shared().flippedTableView
    }
}

// MARK: IBActions

extension DevModeViewController {
        
    @IBAction func resetModalDefaults(_ sender: Any) {
        let defaults = AppGroup.userDefaults()
        
        defaults?.set(false, forKey: Constants.showed10YearsAnniversaryView)
        
        defaults?.synchronize()
        
        NotificationPresenterWrapper.shared.present(type: .generalSuccess)
    }
    
    @IBAction func donateInteractionsValueChanged(_ sender: UISwitch) {
        UserSettings.shared().donateInteractions = sender.isOn
        if !sender.isOn {
            DispatchQueue.main.async {
                INInteraction.deleteAll { error in
                    if error != nil {
                        DDLogError("[PrivacySettingsViewController] Could not delete INInteractions.")
                    }
                }
            }
        }
    }

    @IBAction func newChatViewValueChanged(_ sender: UISwitch) {
        UserSettings.shared().newChatViewActive = sender.isOn
    }

    @IBAction func allowSeveralLinkedDevicesValueChanged(_ sender: UISwitch) {
        UserSettings.shared().allowSeveralLinkedDevices = sender.isOn
    }
    
    @IBAction func initialScrollPositionAlternative1ValueChanged(_ sender: UISwitch) {
        UserSettings.shared().initialScrollPositionAlt1 = sender.isOn
    }
    
    @IBAction func flippedTableViewSwitchValueChanged(_ sender: UISwitch) {
        UserSettings.shared().flippedTableView = sender.isOn
    }
}
