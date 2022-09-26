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

import Foundation

class FontSizeViewController: ThemedTableViewController {
    private var selectedIndexPath: IndexPath?
    private let businessInjector = BusinessInjector()
    private let fontSizes = [12, 14, 16, 18, 20, 24, 28, 30, 36]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = BundleUtil.localizedString(forKey: "font_size_title")
    }
}

// MARK: - UITableViewDataSource

extension FontSizeViewController {
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        fontSizes.count + 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FontSizeCell", for: indexPath)
        
        if indexPath.row == fontSizes.count {
            cell.textLabel?.font = UIFont.preferredFont(forTextStyle: .body)
            cell.textLabel?.text = BundleUtil.localizedString(forKey: "use_dynamic_font_size")
            
            if businessInjector.userSettings.useDynamicFontSize {
                selectedIndexPath = indexPath
                cell.accessoryType = .checkmark
            }
            else {
                cell.accessoryType = .none
            }
        }
        else {
            cell.textLabel?.font = UIFont.systemFont(ofSize: CGFloat(fontSizes[indexPath.row]))
            cell.textLabel?.text = String.localizedStringWithFormat(
                BundleUtil.localizedString(forKey: "font_size"),
                fontSizes[indexPath.row]
            )
            
            if Int(businessInjector.userSettings.chatFontSize) == fontSizes[indexPath.row],
               !businessInjector.userSettings.useDynamicFontSize {
                selectedIndexPath = indexPath
                cell.accessoryType = .checkmark
            }
            else {
                cell.accessoryType = .none
            }
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension FontSizeViewController {
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if indexPath.row == fontSizes.count {
            businessInjector.userSettings.useDynamicFontSize = true
        }
        else {
            businessInjector.userSettings.chatFontSize = Float(fontSizes[indexPath.row])
            businessInjector.userSettings.useDynamicFontSize = false
        }
        
        if let path = selectedIndexPath {
            tableView.cellForRow(at: path)?.accessoryType = .none
        }
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
        tableView.deselectRow(at: indexPath, animated: true)
        selectedIndexPath = indexPath
    }
}
