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

class MasterDndDaysViewController: ThemedTableViewController {
    
    var days: [String] = Calendar.current.weekdaySymbols
    var selectedIndexPaths = NSMutableOrderedSet()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = BundleUtil.localizedString(forKey: "settings_notifications_masterDnd_workingDays")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        selectedIndexPaths = NSMutableOrderedSet(orderedSet: UserSettings.shared().masterDndWorkingDays)
        
        tableView.reloadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        UserSettings.shared().masterDndWorkingDays = selectedIndexPaths
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        days.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MasterDndDaysCell", for: indexPath)
        
        var row = indexPath.row + Calendar.current.firstWeekday
        if row > days.count {
            row = row - days.count
        }
        cell.textLabel?.text = days[row - 1]
        if selectedIndexPaths.contains(row) {
            cell.accessoryType = .checkmark
        }
        else {
            cell.accessoryType = .none
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        var row = indexPath.row + Calendar.current.firstWeekday
        if row > days.count {
            row = row - days.count
        }
        if selectedIndexPaths.contains(row) {
            selectedIndexPaths.remove(row)
            cell?.accessoryType = .none
        }
        else {
            selectedIndexPaths.add(row)
            cell?.accessoryType = .checkmark
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
