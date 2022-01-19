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

class MediaShareOptionsViewController: UITableViewController {
    
    @IBOutlet weak var sendAsFileSwitch: UISwitch!
    
    struct ImageSendOptions {
        var sendAsFile = false
        var imageQuality = ""
    }
    
    var options: ImageSendOptions?
    @IBOutlet weak var imageSizeLabel: UILabel!
    weak var delegate: MediaPreviewViewController?
    
    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var navigationBar: UINavigationItem!
    @IBOutlet weak var sendAsFileCell: UITableViewCell!
    @IBOutlet weak var imageQualityCell: UITableViewCell!
    
    
    func setupOptions(options : ImageSendOptions) {
        self.options = options
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        self.options!.imageQuality = BundleUtil.localizedString(forKey: UserSettings.shared().imageSize)
        self.sendAsFileSwitch.isOn = self.options?.sendAsFile ?? false
        self.navigationBar.title = BundleUtil.localizedString(forKey: "more_options")
        self.sendAsFileCell.textLabel?.text = BundleUtil.localizedString(forKey: "send_as_file")
        saveButton.title = BundleUtil.localizedString(forKey: "Done")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        saveOptions()
        super.viewWillDisappear(animated)
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
         return BundleUtil.localizedString(forKey: "send_as_file_description")
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return BundleUtil.localizedString(forKey: "send_as_file_title")
    }
    
    @IBAction func donePressed(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
        saveOptions()
    }
    
    func saveOptions() {
        self.options?.sendAsFile = self.sendAsFileSwitch.isOn
        self.delegate?.updateOptions(imageSendOptions: self.options!)
    }
}
