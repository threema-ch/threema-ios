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

class TypingIndicatorsSettingsViewController: ThemedTableViewController {
    
    private var settingsStore: SettingsStore
    private var settings: SettingsStore.Settings
    
    private var lastSelected: IndexPath {
        if UserSettings.shared().sendTypingIndicator {
            return IndexPath(row: 0, section: 0)
        }
        else {
            return IndexPath(row: 1, section: 0)
        }
    }
    
    override init(style: UITableView.Style) {
        
        self.settingsStore = SettingsStore()
        self.settings = settingsStore.settings
        
        super.init(style: style)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        title = BundleUtil.localizedString(forKey: "send_typingIndicators")
    }
}

// MARK: - TableView

extension TypingIndicatorsSettingsViewController {
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
       
        switch section {
        case 0:
            return 2
        case 1:
            return 1
        default:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "defaultCell")
        
        // Section 0
        if indexPath.section == 0 {
            if indexPath.row == 0 {
                cell.textLabel?.text = BundleUtil.localizedString(forKey: "send")
                if UserSettings.shared().sendTypingIndicator {
                    cell.accessoryType = .checkmark
                }
            }
            else if indexPath.row == 1 {
                cell.textLabel?.text = BundleUtil.localizedString(forKey: "dont_send")
                if !UserSettings.shared().sendTypingIndicator {
                    cell.accessoryType = .checkmark
                }
            }
            // Section 1
        }
        else if indexPath.section == 1 {
            cell.textLabel?.text = BundleUtil.localizedString(forKey: "reset_overrides")
        }
        
        return cell
    }
    
    override func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        super.tableView(tableView, willDisplay: cell, forRowAt: indexPath)

        if indexPath.section == 1 {
            cell.textLabel?.textColor = Colors.red
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return BundleUtil.localizedString(forKey: "default_setting")
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 1 {
            return BundleUtil.localizedString(forKey: "resetButton_footer")
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        if indexPath.section == 0 {

            // Update checkmark
            tableView.cellForRow(at: lastSelected)?.accessoryType = .none
            tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
           
            if indexPath.row == 0 {
                // Set default to send
                settings.sendTypingIndicator = true
            }
            else if indexPath.row == 1 {
                // Set default to don't send
                settings.sendTypingIndicator = false
            }
            attemptSave()
        }
        else if indexPath.section == 1 {
            UIAlertTemplate.showDestructiveAlert(
                owner: self,
                title: BundleUtil.localizedString(forKey: "reset_overrides_alert_title"),
                message: BundleUtil.localizedString(forKey: "reset_overrides_alert_message"),
                titleDestructive: BundleUtil.localizedString(forKey: "reset_overrides_alert_action")
            ) { _ in
                self.resetContactsToDefault()
            }
        }
        
        // Deselect Row
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - Other

extension TypingIndicatorsSettingsViewController {
    
    private func resetContactsToDefault() {
        let entityManager = EntityManager()
        
        guard let contacts = entityManager.entityFetcher.contactsWithCustomTypingIndicator() as? [Contact] else {
            return
        }
        
        entityManager.performSyncBlockAndSafe {
            for contact in contacts {
                contact.typingIndicator = .default
            }
        }
    }
    
    private func attemptSave() {
        if ServerConnector.shared().isMultiDeviceActivated {
            let syncHelper = UISyncHelper(
                viewController: self,
                progressString: BundleUtil.localizedString(forKey: "syncing_settings"),
                navigationController: navigationController
            )
            
            syncHelper.execute(settings: settings)
                .catch { error in
                    DDLogWarn("Unable to sync privacy settings: \(error.localizedDescription)")
                }
        }
        else {
            settingsStore.save(settings)
        }
    }
}
