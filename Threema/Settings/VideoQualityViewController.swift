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

class VideoQualityViewController: ThemedTableViewController {
    
    // MARK: - Private properties

    private var selectedIndexPath: IndexPath?
    private let businessInjector = BusinessInjector()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = BundleUtil.localizedString(forKey: "videoquality_title")
    }
}

// MARK: - UITableViewDataSource

extension VideoQualityViewController {
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        MediaConverter.videoQualities().count
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 0 {
            return BundleUtil.localizedString(forKey: "still_compressed_note")
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "VideoQualityCell", for: indexPath)
        let quality = MediaConverter.videoQualities()[indexPath.row]
        cell.textLabel?.text = BundleUtil.localizedString(forKey: quality)
        
        if indexPath.row < 2 {
            let maxDuration = MediaConverter.videoQualityMaxDurations()[indexPath.row]
            if maxDuration.intValue == 1 {
                cell.detailTextLabel?.text = BundleUtil.localizedString(forKey: "max_1_minute")
            }
            else {
                cell.detailTextLabel?.text = String.localizedStringWithFormat(
                    BundleUtil.localizedString(forKey: "max_x_minutes"),
                    maxDuration.intValue
                )
            }
        }
        else {
            cell.detailTextLabel?.text = nil
        }
        
        if businessInjector.userSettings.videoQuality == quality {
            cell.accessoryType = .checkmark
            selectedIndexPath = indexPath
        }
        else {
            cell.accessoryType = .none
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension VideoQualityViewController {
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        businessInjector.userSettings.videoQuality = MediaConverter.videoQualities()[indexPath.row]
        
        if let selected = selectedIndexPath {
            tableView.cellForRow(at: selected)?.accessoryType = .none
        }
        
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
        tableView.deselectRow(at: indexPath, animated: true)
        selectedIndexPath = indexPath
    }
}
