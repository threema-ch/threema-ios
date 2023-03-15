//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2023 Threema GmbH
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

class MediaSettingsViewController: ThemedTableViewController {

    @IBOutlet var imageSizeLabel: UILabel!
    @IBOutlet var videoQualityLabel: UILabel!
    @IBOutlet var autoSaveMediaSwitch: UISwitch!
    @IBOutlet var autoSaveMediaLabel: UILabel!
    @IBOutlet var autoSaveMediaCell: UITableViewCell!
    
    let mdmSetup: MDMSetup
    
    required init?(coder aDecoder: NSCoder) {
        self.mdmSetup = MDMSetup(setup: false)
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        imageSizeLabel.text = BundleUtil.localizedString(forKey: UserSettings.shared().imageSize)
        videoQualityLabel.text = BundleUtil.localizedString(forKey: UserSettings.shared().videoQuality)

        autoSaveMediaCell.isUserInteractionEnabled = !mdmSetup.existsMdmKey(MDM_KEY_DISABLE_SAVE_TO_GALLERY)
        autoSaveMediaLabel.isEnabled = !mdmSetup.existsMdmKey(MDM_KEY_DISABLE_SAVE_TO_GALLERY)
        autoSaveMediaSwitch.isOn = UserSettings.shared().autoSaveMedia

        updateColors()
        
        tableView.reloadData()
    }

    // MARK: - Table view data source
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 0 {
            var footerText = ""
            if mdmSetup.existsMdmKey(MDM_KEY_DISABLE_SAVE_TO_GALLERY) {
                footerText.append(BundleUtil.localizedString(forKey: "disabled_by_device_policy"))
            }
            
            if UserSettings.shared()?.imageSize == "original" || UserSettings.shared()?.imageSize == "xlarge" {
                if !footerText.isEmpty {
                    footerText.append("\n\n")
                }
                footerText.append(BundleUtil.localizedString(forKey: "image_resize_share_extension"))
            }
            
            if UserSettings.shared().autoSaveMedia {
                if !footerText.isEmpty {
                    footerText.append("\n\n")
                }
                footerText.append(BundleUtil.localizedString(forKey: "settings_media_autosave_private_footer"))
            }
            
            if !footerText.isEmpty {
                return footerText
            }
        }
        return nil
    }
    
    override func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        super.tableView(tableView, willDisplay: cell, forRowAt: indexPath)
        updateColors()
    }
    
    @IBAction func autoSaveMediaChanged(_ sender: UISwitch) {
        UserSettings.shared().autoSaveMedia = autoSaveMediaSwitch.isOn
        tableView.reloadData()
    }
}
