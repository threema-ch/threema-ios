//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2021 Threema GmbH
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

    @IBOutlet weak var imageSizeLabel: UILabel!
    @IBOutlet weak var videoQualityLabel: UILabel!
    @IBOutlet weak var autoSaveMediaSwitch: UISwitch!
    @IBOutlet weak var autoSaveMediaLabel: UILabel!
    @IBOutlet weak var autoSaveMediaCell: UITableViewCell!
    
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
        
        self.imageSizeLabel.text = BundleUtil.localizedString(forKey: UserSettings.shared().imageSize)
        self.videoQualityLabel.text = BundleUtil.localizedString(forKey: UserSettings.shared().videoQuality)

        self.autoSaveMediaCell.isUserInteractionEnabled = !mdmSetup.existsMdmKey(MDM_KEY_DISABLE_SAVE_TO_GALLERY)
        self.autoSaveMediaLabel.isEnabled = !mdmSetup.existsMdmKey(MDM_KEY_DISABLE_SAVE_TO_GALLERY)
        self.autoSaveMediaSwitch.isOn = UserSettings.shared().autoSaveMedia

        self.updateColors()
        
        self.tableView.reloadData()
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if #available(iOS 11.0, *) {
            if section == 0 {
                return 38.0
            }
        }
        
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 0 {
            var footerText = ""
            if mdmSetup.existsMdmKey(MDM_KEY_DISABLE_SAVE_TO_GALLERY) {
                footerText.append(BundleUtil.localizedString(forKey: "disabled_by_device_policy"))
            }
            
            if UserSettings.shared()?.imageSize == "original" || UserSettings.shared()?.imageSize == "xlarge" {
                if footerText.count > 0 {
                    footerText.append("\n\n")
                }
                footerText.append(BundleUtil.localizedString(forKey: "image_resize_share_extension"))
            }
            if footerText.count > 0 {
                return footerText
            }
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        Colors.update(cell)
        self.updateColors()
    }
    
    @IBAction func autoSaveMediaChanged(_ sender: UISwitch) {
        UserSettings.shared().autoSaveMedia = self.autoSaveMediaSwitch.isOn
    }
    
    func updateColors() {
    }
}
