//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2024 Threema GmbH
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

class SyncExclusionListViewController: ThemedTableViewController {
    
    private var settingsStore: SettingsStoreProtocol

    required init?(coder: NSCoder) {
        self.settingsStore = BusinessInjector().settingsStore
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = editButtonItem
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateView()
        
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
        NotificationPresenterWrapper.shared.present(type: .settingsSyncSuccess)
    }
    
    func updateView() {
        tableView.reloadData()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        settingsStore.syncExclusionList.count + 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row < settingsStore.syncExclusionList.count {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ExclusionCell")!
            cell.textLabel?.text = settingsStore.syncExclusionList[indexPath.row]
            return cell
        }
        else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "AddCell")!
            cell.imageView?.image = UIImage(named: "AddMember", in: .primary)
            return cell
        }
    }
    
    override func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        if editingStyle == .delete {
            var newArray = [String](settingsStore.syncExclusionList)
            newArray.remove(at: indexPath.row)
            settingsStore.syncExclusionList = newArray
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == settingsStore.syncExclusionList.count {
            let title = BundleUtil.localizedString(forKey: "enter_id_to_exclude")
            let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
            alert.addTextField(configurationHandler: nil)
            
            let okTitle = BundleUtil.localizedString(forKey: "ok")
            let okAction = UIAlertAction(title: okTitle, style: .default) { _ in
                self.tableView.deselectRow(at: indexPath, animated: true)
                
                guard let excludeID = alert.textFields?.first?.text?.uppercased() else {
                    DDLogError("Text for ExcludeID was nil")
                    return
                }
                
                if excludeID.count == kIdentityLen {
                    var set = Set(self.settingsStore.syncExclusionList)
                    set.insert(excludeID)
                    self.settingsStore.syncExclusionList = set
                        .sorted { $0.caseInsensitiveCompare($1) == .orderedAscending }
                    self.tableView.reloadData()
                }
                else {
                    alert.dismiss(animated: true) {
                        let title = BundleUtil.localizedString(forKey: "settings_privacy_exclusion_list_alert_title")
                        let message = BundleUtil
                            .localizedString(forKey: "settings_privacy_exclusion_list_alert_message")
                        UIAlertTemplate.showAlert(owner: self, title: title, message: message)
                    }
                }
            }
            
            let cancelTitle = BundleUtil.localizedString(forKey: "cancel")
            let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel) { _ in
                self.tableView.deselectRow(at: indexPath, animated: true)
            }
            
            alert.addAction(okAction)
            alert.addAction(cancelAction)
            present(alert, animated: true, completion: nil)
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        indexPath.row < settingsStore.syncExclusionList.count
    }
}
