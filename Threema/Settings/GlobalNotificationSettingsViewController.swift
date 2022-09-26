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

class GlobalNotificationSettingsViewController: ThemedTableViewController {
    
    @IBOutlet var inAppSoundsSwitch: UISwitch!
    @IBOutlet var inAppVibrateSwitch: UISwitch!
    @IBOutlet var inAppPreviewSwitch: UISwitch!
    @IBOutlet var inAppSoundsLabel: UILabel!
    @IBOutlet var inAppVibrateLabel: UILabel!
    @IBOutlet var inAppPreviewLabel: UILabel!
    
    @IBOutlet var pushSoundLabel: UILabel!
    @IBOutlet var pushGroupSoundLabel: UILabel!
    @IBOutlet var pushDecryptLabel: UILabel!
    @IBOutlet var pushShowNicknameLabel: UILabel!
    
    @IBOutlet var pushSoundValueLabel: UILabel!
    @IBOutlet var pushGroupSoundValueLabel: UILabel!
    @IBOutlet var pushGroupSoundCell: UITableViewCell!
    @IBOutlet var pushDecryptSwitch: UISwitch!
    
    @IBOutlet var pushPreviewCell: UITableViewCell!
    
    @IBOutlet var pushShowNicknameSwitch: UISwitch!
    
    @IBOutlet var masterDndLabel: UILabel!
    @IBOutlet var masterDndSwitch: UISwitch!
    
    @IBOutlet var masterDndDaysCell: UITableViewCell!
    @IBOutlet var masterDndStartTimeCell: UITableViewCell!
    @IBOutlet var masterDndEndTimeCell: UITableViewCell!
    @IBOutlet var masterDndDaysLabel: UILabel!
    @IBOutlet var masterDndDaysValueLabel: UILabel!
    @IBOutlet var masterDndStartTimeLabel: UILabel!
    @IBOutlet var masterDndStartTimeValueLabel: UILabel!
    @IBOutlet var masterDndEndTimeLabel: UILabel!
    @IBOutlet var masterDndEndTimeValueLabel: UILabel!
    
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
        
        tableView.register(
            UINib(nibName: TimePickerCell.nibName(), bundle: nil),
            forCellReuseIdentifier: TimePickerCell.reuseIdentifier()
        )
        tableView.registerCell(ActionDetailsTableViewCell.self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setupSwitches()
        setupLabels()
        
        tableView.reloadData()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "EditPushGroupSound" {
            if let psvc = segue.destination as? PushSoundViewController {
                psvc.isGroup = true
            }
        }
    }
    
    // MARK: Private functions
    
    private func setupSwitches() {
        inAppSoundsSwitch.isOn = UserSettings.shared().inAppSounds
        inAppVibrateSwitch.isOn = UserSettings.shared().inAppVibrate
        inAppPreviewSwitch.isOn = UserSettings.shared().inAppPreview
        pushShowNicknameSwitch.isOn = UserSettings.shared().pushShowNickname
        pushDecryptSwitch.isOn = UserSettings.shared().pushDecrypt
        masterDndSwitch.isOn = UserSettings.shared().enableMasterDnd
        
        pushDecryptSwitch.isEnabled = !mdmSetup.existsMdmKey(MDM_KEY_DISABLE_MESSAGE_PREVIEW)
    }
    
    private func setupLabels() {
        inAppSoundsLabel.text = BundleUtil.localizedString(forKey: "settings_notifications_inapp_sounds")
        inAppVibrateLabel.text = BundleUtil.localizedString(forKey: "settings_notifications_inapp_vibrate")
        inAppPreviewLabel.text = BundleUtil.localizedString(forKey: "settings_notifications_inapp_preview")
        
        pushSoundLabel.text = BundleUtil.localizedString(forKey: "settings_notifications_push_sound")
        pushGroupSoundLabel.text = BundleUtil.localizedString(forKey: "settings_notifications_push_groupsound")
        pushDecryptLabel.text = BundleUtil.localizedString(forKey: "settings_notifications_push_preview")
        pushShowNicknameLabel.text = BundleUtil.localizedString(forKey: "settings_notifications_push_showNickname")
        
        let pushSoundName = "sound_\(UserSettings.shared().pushSound!)"
        pushSoundValueLabel.text = BundleUtil.localizedString(forKey: pushSoundName)
        
        let pushGroupSoundName = "sound_\(UserSettings.shared().pushGroupSound!)"
        pushGroupSoundValueLabel.text = BundleUtil.localizedString(forKey: pushGroupSoundName)
        
        masterDndLabel.text = BundleUtil.localizedString(forKey: "settings_notifications_masterDnd")
        masterDndDaysLabel.text = BundleUtil.localizedString(forKey: "settings_notifications_masterDnd_workingDays")
        
        var workingDayShortString = ""
        let workingDays = UserSettings.shared().masterDndWorkingDays!
        
        // swiftformat:disable:next isEmpty
        if workingDays.count > 0 {
            let sortedWorkingDays = workingDays.sortedArray { a, b -> ComparisonResult in
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
                if !workingDayShortString.isEmpty {
                    workingDayShortString.append(", ")
                }
                workingDayShortString.append(Calendar.current.shortWeekdaySymbols[(dayNumber as! Int) - 1])
            }
            masterDndDaysValueLabel.text = workingDayShortString
        }
        else {
            masterDndDaysValueLabel.text = ""
        }
        
        masterDndStartTimeLabel.text = BundleUtil.localizedString(forKey: "settings_notifications_masterDnd_startTime")
        masterDndStartTimeValueLabel.text = UserSettings.shared().masterDndStartTime
        masterDndEndTimeLabel.text = BundleUtil.localizedString(forKey: "settings_notifications_masterDnd_endTime")
        masterDndEndTimeValueLabel.text = UserSettings.shared().masterDndEndTime
        
        pushDecryptLabel.isEnabled = !mdmSetup.existsMdmKey(MDM_KEY_DISABLE_MESSAGE_PREVIEW)
    }
    
    // MARK: IBActions
    
    @IBAction func inAppSoundsChanged(sender: UISwitch) {
        UserSettings.shared().inAppSounds = inAppSoundsSwitch.isOn
    }
    
    @IBAction func inAppVibrateChanged(sender: UISwitch) {
        UserSettings.shared().inAppVibrate = inAppVibrateSwitch.isOn
    }
    
    @IBAction func inAppPreviewChanged(sender: UISwitch) {
        UserSettings.shared().inAppPreview = inAppPreviewSwitch.isOn
    }
    
    @IBAction func pushDecryptChanged(sender: UISwitch) {
        UserSettings.shared().pushDecrypt = pushDecryptSwitch.isOn
    }
    
    @IBAction func pushShowNicknameChanged(sender: UISwitch) {
        UserSettings.shared()?.pushShowNickname = pushShowNicknameSwitch.isOn
    }
    
    @IBAction func masterDndChanged(sender: UISwitch) {
        UserSettings.shared().enableMasterDnd = sender.isOn
        tableView.beginUpdates()
        if let timePickerIndexPath = timePickerIndexPath {
            tableView.deleteRows(at: [timePickerIndexPath], with: .fade)
            self.timePickerIndexPath = nil
            selectedCellForPickerIndexPath = nil
        }
        tableView.reloadSections(IndexSet(integer: 2), with: .none)
        tableView.endUpdates()
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        if LicenseStore.requiresLicenseKey() {
            return 4
        }
        return 3
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if timePickerIndexPath != nil, section == timePickerIndexPath?.section {
            return super.tableView(tableView, numberOfRowsInSection: section) + 1
        }
        
        if (section == 2 && !masterDndSwitch.isOn) || section == numberOfSections(in: tableView) - 1 {
            return 1
        }
        
        return super.tableView(tableView, numberOfRowsInSection: section)
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        if timePickerIndexPath == indexPath {
            return TimePickerCell.cellHeight()
        }
        else {
            return super.tableView(tableView, estimatedHeightForRowAt: indexPath)
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if timePickerIndexPath == indexPath {
            return TimePickerCell.cellHeight()
        }
        else {
            return super.tableView(tableView, heightForRowAt: indexPath)
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if timePickerIndexPath == indexPath {
            let dateCell = tableView.cellForRow(at: selectedCellForPickerIndexPath!)
            let datePickerCell = tableView
                .dequeueReusableCell(withIdentifier: TimePickerCell.reuseIdentifier()) as! TimePickerCell
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
        }
        else {
            if timePickerIndexPath != nil, indexPath.section == 2, indexPath.row >= timePickerIndexPath!.row {
                let newIndexPath = IndexPath(row: indexPath.row - 1, section: indexPath.section)
                return super.tableView(tableView, cellForRowAt: newIndexPath)
            }
            else if indexPath.section == numberOfSections(in: tableView) - 1 {
                let actionCell: ActionDetailsTableViewCell = tableView.dequeueCell(for: indexPath)
                actionCell.action = goToSettings()
                return actionCell
            }
            else {
                return super.tableView(tableView, cellForRowAt: indexPath)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, indentationLevelForRowAt indexPath: IndexPath) -> Int {
        0
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return BundleUtil.localizedString(forKey: "settings_notifications_inapp_section")
        case 1:
            return BundleUtil.localizedString(forKey: "settings_notifications_push_section")
        case 2:
            if LicenseStore.requiresLicenseKey() {
                return BundleUtil.localizedString(forKey: "settings_notifications_masterDnd_section_header")
            }
            return BundleUtil.localizedString(forKey: "settings_notification_open_iOS_settings")
        case 3:
            return BundleUtil.localizedString(forKey: "settings_notification_open_iOS_settings")
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
        case 2:
            if LicenseStore.requiresLicenseKey() {
                return BundleUtil.localizedString(forKey: "settings_notifications_masterDnd_section_footer")
            }
            return nil
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
            if let timePickerIndexPath = timePickerIndexPath, timePickerIndexPath.row - 1 == indexPath.row {
                tableView.deleteRows(at: [timePickerIndexPath], with: .fade)
                self.timePickerIndexPath = nil
                selectedCellForPickerIndexPath = nil
            }
            else {
                if let timePickerIndexPath = timePickerIndexPath {
                    tableView.deleteRows(at: [timePickerIndexPath], with: .fade)
                }
                timePickerIndexPath = indexPathToInsertTimePicker(indexPath: indexPath)
                selectedCellForPickerIndexPath = indexPath
                tableView.insertRows(at: [timePickerIndexPath!], with: .fade)
                scrollToPicker = true
            }
            tableView.endUpdates()
        }
        else {
            if let timePickerIndexPath = timePickerIndexPath {
                tableView.beginUpdates()
                tableView.deleteRows(at: [timePickerIndexPath], with: .fade)
                self.timePickerIndexPath = nil
                selectedCellForPickerIndexPath = nil
                tableView.endUpdates()
            }
            if let actionCell = cell as? ActionDetailsTableViewCell,
               indexPath.section == numberOfSections(in: tableView) - 1 {
                actionCell.action?.run(actionCell)
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
        }
        else {
            return IndexPath(row: indexPath.row + 1, section: indexPath.section)
        }
    }
    
    private func timeOfDayFromTimeString(timeString: String) -> TimeOfDay {
        let components: [String] = timeString.components(separatedBy: ":")
        return TimeOfDay(hour: Int(components[0])!, minute: Int(components[1])!)
    }
    
    private func dateFromTimeString(timeString: String) -> Date {
        let components: [String] = timeString.components(separatedBy: ":")
        return Calendar.current.date(
            bySettingHour: Int(components[0])!,
            minute: Int(components[1])!,
            second: 0,
            of: Date()
        )!
    }
    
    private func goToSettings() -> Details.Action {
        let goToSettingsAction = Details.Action(
            title: BundleUtil.localizedString(forKey: "settings_notification_iOS_settings")
        ) { _ in
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        }
        
        return goToSettingsAction
    }
}

// MARK: - TimePickerDelegate

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
                masterDndStartTimeValueLabel.text = newTimeString
            }
            else {
                if timePickerIndexPath != nil {
                    if let datePickerCell = tableView.cellForRow(at: timePickerIndexPath!) as? TimePickerCell {
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
                masterDndEndTimeValueLabel.text = newTimeString
            }
            else {
                if timePickerIndexPath != nil {
                    if let datePickerCell = tableView.cellForRow(at: timePickerIndexPath!) as? TimePickerCell {
                        let date = dateFromTimeString(timeString: UserSettings.shared().masterDndEndTime)
                        datePickerCell.updateCell(date: date, indexPath: timePickerIndexPath!)
                    }
                }
            }
        }
    }
}
