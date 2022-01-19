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

import Foundation

class ThreemaVideoCallQualityViewController: ThemedTableViewController {
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.title = BundleUtil.localizedString(forKey: "settings_threema_calls_video_quality_profile")
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return CallsignalingProtocol.threemaVideoCallQualitySettingCount()
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let qualitySettingItem = ThreemaVideoCallQualitySetting.init(UInt32(indexPath.row))
        let cell = tableView.dequeueReusableCell(withIdentifier: "ThreemaVideoCallQualitySettingCell", for: indexPath)
        cell.textLabel?.text = CallsignalingProtocol.threemaVideoCallQualitySettingTitle(for: qualitySettingItem)
        cell.detailTextLabel?.text = CallsignalingProtocol.threemaVideoCallQualitySettingSubtitle(for: qualitySettingItem)
        cell.accessoryType = CallsignalingProtocol.threemaVideoCallQualitySettingSelected(for: qualitySettingItem) ? .checkmark : .none
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let qualitySettingItem = ThreemaVideoCallQualitySetting.init(UInt32(indexPath.row))
        UserSettings.shared()?.threemaVideoCallQualitySetting = qualitySettingItem
        NotificationCenter.default.post(name: NSNotification.Name(kThreemaVideoCallsQualitySettingChanged), object: nil)
        tableView.reloadData()
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return BundleUtil.localizedString(forKey: "settings_threema_calls_video_quality_profile_footer")
    }
}
