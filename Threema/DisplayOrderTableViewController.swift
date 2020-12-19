//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2017-2020 Threema GmbH
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

class DisplayOrderTableViewController: ThemedTableViewController {
    
    var sortings:[String] = []
    var selectedIndexPath:IndexPath? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        
        sortings = ["Firstname", "Lastname"]
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        tableView.reloadData()
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sortings.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DisplayOrderCell", for: indexPath)
        let orderKey = "SortOrder_\(sortings[indexPath.row])"
        cell.textLabel?.text = NSLocalizedString(orderKey, comment: "")
        
        if (UserSettings.shared().displayOrderFirstName && indexPath.row == 0) || (!UserSettings.shared().displayOrderFirstName && indexPath.row == 1) {
            selectedIndexPath = indexPath
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        UserSettings.shared().displayOrderFirstName = indexPath.row == 0 ? true : false
        
        if selectedIndexPath != nil {
            tableView.cellForRow(at: selectedIndexPath!)?.accessoryType = .none
        }
        
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
        tableView.deselectRow(at: indexPath, animated: true)
        selectedIndexPath = indexPath
    }
}
