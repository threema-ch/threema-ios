//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2021 Threema GmbH
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

class GlobalNotificationSettingsViewController: ThemedTableViewController {

    @IBOutlet weak var inAppSoundsSwitch: UISwitch!
    @IBOutlet weak var inAppVibrateSwitch: UISwitch!
    @IBOutlet weak var inAppPreviewSwitch: UISwitch!
    @IBOutlet weak var inAppSoundsLabel: UILabel!
    @IBOutlet weak var inAppVibrateLabel: UILabel!
    @IBOutlet weak var inAppPreviewLabel: UILabel!
        
    @IBOutlet weak var pushSoundLabel: UILabel!
    @IBOutlet weak var pushGroupSoundLabel: UILabel!
    @IBOutlet weak var pushDecryptLabel: UILabel!
    @IBOutlet weak var pushShowNicknameLabel: UILabel!
    
    @IBOutlet weak var pushSoundValueLabel: UILabel!
    @IBOutlet weak var pushGroupSoundValueLabel: UILabel!
    @IBOutlet weak var pushGroupSoundCell: UITableViewCell!
    @IBOutlet weak var pushDecryptSwitch: UISwitch!
    
    @IBOutlet weak var pushPreviewCell: UITableViewCell!
    
    @IBOutlet weak var voIPSoundLabel: UILabel!
    @IBOutlet weak var voIPSoundValueLabel: UILabel!
    @IBOutlet weak var pushShowNicknameSwitch: UISwitch!
    
    @IBOutlet weak var masterDndLabel: UILabel!
    @IBOutlet weak var masterDndSwitch: UISwitch!
    
    @IBOutlet weak var masterDndDaysCell: UITableViewCell!
    @IBOutlet weak var masterDndStartTimeCell: UITableViewCell!
    @IBOutlet weak var masterDndEndTimeCell: UITableViewCell!
    @IBOutlet weak var masterDndDaysLabel: UILabel!
    @IBOutlet weak var masterDndDaysValueLabel: UILabel!
    @IBOutlet weak var masterDndStartTimeLabel: UILabel!
    @IBOutlet weak var masterDndStartTimeValueLabel: UILabel!
    @IBOutlet weak var masterDndEndTimeLabel: UILabel!
    @IBOutlet weak var masterDndEndTimeValueLabel: UILabel!
    
    let mdmSetup: MDMSetup
    
    var timePickerIndexPath: IndexPath?
    var selectedCellForPickerIndexPath: IndexPath?
    
    typealias TimeOfDay = (hour: Int, minute: Int)
    
    required init?(coder aDecoder: NSCoder) {
        self.mdmSetup = MDMSetup(setup: false)
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(UINib(nibName: TimePickerwCell.nibName(), bundle: nil), forCellReuseIdentifier: TimePickerwCell.reuseIdentifier())
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.setupSwitches()
        self.setupLabels()
        
        self.tableView.reloadData()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "EditPushGroupSound" {
            if let psvc = segue.destination as? PushSoundViewController {
                psvc.group = true
            }
        }
    }
    
    // MARK Private functions
    
    private func setupSwitches() {
        self.inAppSoundsSwitch.isOn = UserSettings.shared().inAppSounds
        self.inAppVibrateSwitch.isOn = UserSettings.shared().inAppVibrate
        self.inAppPreviewSwitch.isOn = UserSettings.shared().inAppPreview
        self.pushShowNicknameSwitch.isOn = UserSettings.shared().pushShowNickname
        self.pushDecryptSwitch.isOn = UserSettings.shared().pushDecrypt
        self.masterDndSwitch.isOn = UserSettings.shared().enableMasterDnd
    
        self.pushDecryptSwitch.isEnabled = !mdmSetup.existsMdmKey(MDM_KEY_DISABLE_MESSAGE_PREVIEW)

    }
    
    private func setupLabels() {
        self.inAppSoundsLabel.text = BundleUtil.localizedString(forKey: "settings_notifications_inapp_sounds")
        self.inAppVibrateLabel.text = BundleUtil.localizedString(forKey: "settings_notifications_inapp_vibrate")
        self.inAppPreviewLabel.text = BundleUtil.localizedString(forKey: "settings_notifications_inapp_preview")
        
        self.pushSoundLabel.text = BundleUtil.localizedString(forKey: "settings_notifications_push_sound")
        self.pushGroupSoundLabel.text = BundleUtil.localizedString(forKey: "settings_notifications_push_groupsound")
        self.pushDecryptLabel.text = BundleUtil.localizedString(forKey: "settings_notifications_push_preview")
        self.pushShowNicknameLabel.text = BundleUtil.localizedString(forKey: "settings_notifications_push_showNickname")
        
        self.voIPSoundLabel.text = BundleUtil.localizedString(forKey: "settings_notifications_call_sound")
        
        let pushSoundName = "sound_\(UserSettings.shared().pushSound!)"
        self.pushSoundValueLabel.text = BundleUtil.localizedString(forKey: pushSoundName)
        
        let pushGroupSoundName = "sound_\(UserSettings.shared().pushGroupSound!)"
        self.pushGroupSoundValueLabel.text = BundleUtil.localizedString(forKey: pushGroupSoundName)

        let voIPSoundName = "sound_\(UserSettings.shared().voIPSound!)"
        self.voIPSoundValueLabel.text = BundleUtil.localizedString(forKey: voIPSoundName)
        
        self.masterDndLabel.text = BundleUtil.localizedString(forKey: "settings_notifications_masterDnd")
        self.masterDndDaysLabel.text = BundleUtil.localizedString(forKey: "settings_notifications_masterDnd_workingDays")
        
        var workingDayShortString = ""
        let workingDays = UserSettings.shared().masterDndWorkingDays!
        
        if workingDays.count > 0 {
            let sortedWorkingDays = workingDays.sortedArray { (a, b) -> ComparisonResult in
                var dayA = a as! Int
                var dayB = b as! Int
                
                if dayA < Calendar.current.firstWeekday {
                    dayA += Calendar.current.weekdaySymbols.count
                }
                if dayB < Calendar.current.firstWeekday {
                    dayB += Calendar.current.weekdaySymbols.count
                }
                
                if dayA < dayB {
                    return .orderedAscending
                }
                if dayA > dayB {
                    return .orderedDescending
                }
                return .orderedSame
            }
                        
            for dayNumber in sortedWorkingDays {
                if workingDayShortString.count > 0 {
                    workingDayShortString.append(", ")
                }
                workingDayShortString.append(Calendar.current.shortWeekdaySymbols[(dayNumber as! Int)-1])
            }
            self.masterDndDaysValueLabel.text = workingDayShortString
        } else {
            self.masterDndDaysValueLabel.text = ""
        }
        
        self.masterDndStartTimeLabel.text = BundleUtil.localizedString(forKey: "settings_notifications_masterDnd_startTime")
        self.masterDndStartTimeValueLabel.text = UserSettings.shared().masterDndStartTime
        self.masterDndEndTimeLabel.text = BundleUtil.localizedString(forKey: "settings_notifications_masterDnd_endTime")
        self.masterDndEndTimeValueLabel.text = UserSettings.shared().masterDndEndTime

        self.pushDecryptLabel.isEnabled = !mdmSetup.existsMdmKey(MDM_KEY_DISABLE_MESSAGE_PREVIEW)
    }
    
    // MARK IBActions
    
    @IBAction func inAppSoundsChanged(sender: UISwitch) {
        UserSettings.shared().inAppSounds = self.inAppSoundsSwitch.isOn
    }
    
    @IBAction func inAppVibrateChanged(sender: UISwitch) {
        UserSettings.shared().inAppVibrate = self.inAppVibrateSwitch.isOn
    }
    
    @IBAction func inAppPreviewChanged(sender: UISwitch) {
        UserSettings.shared().inAppPreview = self.inAppPreviewSwitch.isOn
    }
    
    @IBAction func pushDecryptChanged(sender: UISwitch) {
        UserSettings.shared().pushDecrypt = self.pushDecryptSwitch.isOn
    }
    
    @IBAction func pushShowNicknameChanged(sender: UISwitch) {
        UserSettings.shared()?.pushShowNickname = self.pushShowNicknameSwitch.isOn
    }
    
    @IBAction func masterDndChanged(sender: UISwitch) {
        UserSettings.shared().enableMasterDnd = sender.isOn
        self.tableView.beginUpdates()
        if let timePickerIndexPath = timePickerIndexPath {
            tableView.deleteRows(at: [timePickerIndexPath], with: .fade)
            self.timePickerIndexPath = nil
            self.selectedCellForPickerIndexPath = nil
        }
        self.tableView.reloadSections(IndexSet(integer: 3), with: .none)
        self.tableView.endUpdates()
    }

    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        if LicenseStore.requiresLicenseKey() == true {
            return 4
        }
        return 3
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if timePickerIndexPath != nil, section == timePickerIndexPath?.section {
            return super.tableView(tableView, numberOfRowsInSection: section) + 1
        }
        if section == 3, !masterDndSwitch.isOn {
            return 1
        }
        return super.tableView(tableView, numberOfRowsInSection: section)
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        if timePickerIndexPath == indexPath {
            return TimePickerwCell.cellHeight()
        } else {
            return super.tableView(tableView, estimatedHeightForRowAt: indexPath)
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if timePickerIndexPath == indexPath {
            return TimePickerwCell.cellHeight()
        } else {
            return super.tableView(tableView, heightForRowAt: indexPath)
        }
    }
        
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if timePickerIndexPath == indexPath {
            let dateCell = tableView.cellForRow(at: selectedCellForPickerIndexPath!)
            let datePickerCell = tableView.dequeueReusableCell(withIdentifier: TimePickerwCell.reuseIdentifier()) as! TimePickerwCell
            var time = "00:00"
            
            if dateCell?.tag == 1 {
                time = UserSettings.shared().masterDndStartTime!
            }
            if dateCell?.tag == 2 {
                time = UserSettings.shared().masterDndEndTime!
            }
            let date = dateFromTimeString(timeString: time)
            datePickerCell.updateCell(date: date, indexPath: indexPath)
            datePickerCell.delegate = self
            return datePickerCell
        } else {
            if timePickerIndexPath != nil, indexPath.section == 3, indexPath.row >= timePickerIndexPath!.row {
                let newIndexPath = IndexPath(row: indexPath.row - 1, section: indexPath.section)
                return super.tableView(tableView, cellForRowAt: newIndexPath)
            } else {
                return super.tableView(tableView, cellForRowAt: indexPath)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, indentationLevelForRowAt indexPath: IndexPath) -> Int {
        return 0
    }

    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return BundleUtil.localizedString(forKey: "settings_notifications_inapp_section")
        case 1:
            return BundleUtil.localizedString(forKey: "settings_notifications_push_section")
        case 2:
            return BundleUtil.localizedString(forKey: "settings_notifications_call_section")
        case 3:
            return BundleUtil.localizedString(forKey: "settings_notifications_masterDnd_section_header")
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 1:
            if mdmSetup.disableMessagePreview() {
                return BundleUtil.localizedString(forKey: "disabled_by_device_policy")
            }
        case 3:
            return BundleUtil.localizedString(forKey: "settings_notifications_masterDnd_section_footer")
        default:
            return nil
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        var scrollToPicker = false
        if cell?.tag == 1 || cell?.tag == 2 {
            tableView.beginUpdates()
            if let timePickerIndexPath = timePickerIndexPath,  timePickerIndexPath.row - 1 == indexPath.row {
                tableView.deleteRows(at: [timePickerIndexPath], with: .fade)
                self.timePickerIndexPath = nil
                self.selectedCellForPickerIndexPath = nil
            } else {
                if let timePickerIndexPath = timePickerIndexPath {
                    tableView.deleteRows(at: [timePickerIndexPath], with: .fade)
                }
                timePickerIndexPath = indexPathToInsertTimePicker(indexPath: indexPath)
                selectedCellForPickerIndexPath = indexPath
                tableView.insertRows(at: [timePickerIndexPath!], with: .fade)
                scrollToPicker = true
            }
            tableView.endUpdates()
        } else {
            if let timePickerIndexPath = timePickerIndexPath {
                tableView.beginUpdates()
                tableView.deleteRows(at: [timePickerIndexPath], with: .fade)
                self.timePickerIndexPath = nil
                self.selectedCellForPickerIndexPath = nil
                tableView.endUpdates()
            }
        }
        
        tableView.deselectRow(at: tableView.indexPathForSelectedRow!, animated: true)
        if scrollToPicker {
            tableView.scrollToRow(at: timePickerIndexPath!, at: .middle, animated: true)
        }
    }
    
    // MARK: private functions
    
    private func indexPathToInsertTimePicker(indexPath: IndexPath) -> IndexPath {
        if let timePickerIndexPath = timePickerIndexPath, timePickerIndexPath.row < indexPath.row {
            return indexPath
        } else {
            return IndexPath(row: indexPath.row + 1, section: indexPath.section)
        }
    }
    
    private func timeOfDayFromTimeString(timeString: String) -> TimeOfDay {
        let components: [String] = timeString.components(separatedBy: ":")
        return TimeOfDay(hour: Int(components[0])!, minute: Int(components[1])!)
    }
    
    private func dateFromTimeString(timeString: String) -> Date {
        let components: [String] = timeString.components(separatedBy: ":")
        return Calendar.current.date(bySettingHour: Int(components[0])!, minute: Int(components[1])!, second: 0, of: Date())!
    }
}

extension GlobalNotificationSettingsViewController: TimePickerDelegate {
    func didChangeTime(date: Date, indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        let calendar = Calendar.current
        
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let newTimeString = String(format: "%02d:%02d", hour, minute)
                
        if cell?.tag == 1 {
            let newStartTime = timeOfDayFromTimeString(timeString: newTimeString)
            let endTime = timeOfDayFromTimeString(timeString: UserSettings.shared().masterDndEndTime)
            
            if newStartTime < endTime {
                UserSettings.shared().masterDndStartTime = newTimeString
                self.masterDndStartTimeValueLabel.text = newTimeString
            } else {
                if timePickerIndexPath != nil {
                    if let datePickerCell = self.tableView.cellForRow(at: timePickerIndexPath!) as? TimePickerwCell {
                        let date = dateFromTimeString(timeString: UserSettings.shared().masterDndStartTime)
                        datePickerCell.updateCell(date: date, indexPath: timePickerIndexPath!)
                    }
                }
            }
        }
        if cell?.tag == 2 {
            let newEndTime = timeOfDayFromTimeString(timeString: newTimeString)
            let startTime = timeOfDayFromTimeString(timeString: UserSettings.shared().masterDndStartTime)
            
            if newEndTime > startTime {
                UserSettings.shared().masterDndEndTime = newTimeString
                self.masterDndEndTimeValueLabel.text = newTimeString
            } else {
                if timePickerIndexPath != nil {
                    if let datePickerCell = self.tableView.cellForRow(at: timePickerIndexPath!) as? TimePickerwCell {
                        let date = dateFromTimeString(timeString: UserSettings.shared().masterDndEndTime)
                        datePickerCell.updateCell(date: date, indexPath: timePickerIndexPath!)
                    }
                }
            }
        }
    }
}
