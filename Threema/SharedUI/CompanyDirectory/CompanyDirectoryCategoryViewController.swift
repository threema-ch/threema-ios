//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2022 Threema GmbH
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

class CompanyDirectoryCategoryViewController: ThemedTableViewController {
    
    var companyDirectoryViewController: CompanyDirectoryViewController?
    private var categoryDict: [String: String] = MyIdentityStore.shared().directoryCategories as! [String: String]
    private let categoryIDArray: [String] = MyIdentityStore.shared().directoryCategoryIDsSortedByName() as! [String]
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        refresh()
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        categoryIDArray.count + 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: "CategoryCell", for: indexPath)
        if indexPath.row == 0 {
            cell.textLabel?.text = BundleUtil.localizedString(forKey: "all")
            cell.accessoryType = companyDirectoryViewController!.filterArray.count == 0 ? .checkmark : .none
        }
        else {
            let catID = categoryIDArray[indexPath.row - 1]
            cell.textLabel?.text = categoryDict[catID]
            cell.accessoryType = companyDirectoryViewController!.filterArray.contains(catID) ? .checkmark : .none
        }
        
        return cell
    }
        
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            companyDirectoryViewController!.filterArray.removeAll()
        }
        else {
            let catID = categoryIDArray[indexPath.row - 1]
            if companyDirectoryViewController!.filterArray.contains(catID) {
                let index = companyDirectoryViewController!.filterArray.firstIndex(of: catID)
                companyDirectoryViewController!.filterArray.remove(at: index!)
            }
            else {
                companyDirectoryViewController!.filterArray.append(catID)
            }
        }
        
        refresh()
    }
}
