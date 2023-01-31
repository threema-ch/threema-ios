//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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
import UIKit

class ImageSizeViewController: ThemedTableViewController {
    
    // MARK: - Private properties

    private var selectedIndexPath: IndexPath?
    private let businessInjector = BusinessInjector()
    private let items = ImageURLSenderItemCreator.imageSizes
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = BundleUtil.localizedString(forKey: "image_size_title")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let footerView = tableView(tableView, viewForFooterInSection: 0) as? UITableViewHeaderFooterView {
            footerView.textLabel?.preferredMaxLayoutWidth = (footerView.textLabel?.frame.size.width)!
            footerView.textLabel?.numberOfLines = 0
        }
        tableView.reloadSections([0], with: .none)
    }
}

// MARK: - UITableView

extension ImageSizeViewController {
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: "ImageSizeCell", for: indexPath)
        let size = items[indexPath.row].rawValue
        let pixels = items[indexPath.row].resolution
        cell.textLabel?.text = BundleUtil.localizedString(forKey: size)
        
        if pixels == 0 {
            cell.detailTextLabel?.text = BundleUtil.localizedString(forKey: "images are not scaled")
        }
        else {
            cell.detailTextLabel?.text = String.localizedStringWithFormat(
                BundleUtil.localizedString(forKey: "max_x_by_x_pixels"),
                Int(pixels),
                Int(pixels)
            )
        }
        
        if businessInjector.userSettings.imageSize == size {
            cell.accessoryType = .checkmark
            selectedIndexPath = indexPath
        }
        else {
            cell.accessoryType = .none
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let selected = selectedIndexPath, selected.row == 3 || selected.row == 4 else {
            return ""
        }
        return BundleUtil.localizedString(forKey: "image_resize_share_extension")
    }
}

// MARK: - UITableViewDelegates

extension ImageSizeViewController {
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        businessInjector.userSettings.imageSize = items[indexPath.row].rawValue
        
        if let selected = selectedIndexPath {
            tableView.cellForRow(at: selected)?.accessoryType = .none
        }
        
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
        tableView.deselectRow(at: indexPath, animated: true)
        
        let lastSelectedIndexPath = selectedIndexPath
        selectedIndexPath = indexPath
        if let lastSelected = lastSelectedIndexPath, let selected = selectedIndexPath,
           ((lastSelected.row < 3) && (selected.row >= 3)) || (lastSelected.row >= 3 && selected.row < 3) {
            tableView.reloadSections([0], with: .none)
        }
    }
}
