//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2022 Threema GmbH
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

protocol DoNotDisturbDelegate {
    func pushSettingChanged(pushSetting: PushSetting)
}

class DoNotDisturbViewController: ThemedTableViewController {
    
    var delegate:DoNotDisturbDelegate?
    var pushSetting:PushSetting!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = UITableView.automaticDimension
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.title = NSLocalizedString("doNotDisturb_title", comment: "")
        
        tableView.reloadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if pushSetting.type == .on {
            pushSetting.periodOffTillDate = nil
        }
        else if pushSetting.type == .off {
            pushSetting.periodOffTillDate = nil
        }
        delegate?.pushSettingChanged(pushSetting: pushSetting)
    }
    
    // MARK: - Table view data source
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if pushSetting.type == .offPeriod {
            return 4
        }
        return 3
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row == 3 {
            return 162
        } else {
           return super.tableView(tableView, heightForRowAt: indexPath)
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row <= 2 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SelectionCell", for: indexPath)
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = NSLocalizedString("doNotDisturb_off", comment: "")
                cell.accessoryType = pushSetting.type == .on ? .checkmark : .none
                break
            case 1:
                cell.textLabel?.text = NSLocalizedString("doNotDisturb_on", comment: "")
                cell.accessoryType = pushSetting.type == .off ? .checkmark : .none
                break
            case 2:
                cell.textLabel?.text = NSLocalizedString("doNotDisturb_onPeriod", comment: "")
                cell.accessoryType = pushSetting.type == .offPeriod ? .checkmark : .none
                break
            default: break
            }
            
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "PickerCell", for: indexPath)
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        if indexPath.row == 0 {
            pushSetting.type = .on
        }
        else if indexPath.row == 1 {
            pushSetting.type = .off
        }
        if indexPath.row == 2 {
            pushSetting.type = .offPeriod
            self.pickerView(UIPickerView(), didSelectRow: 0, inComponent: 0)
        }

        tableView.reloadSections(IndexSet.init(integer: 0), with: .automatic)
        delegate?.pushSettingChanged(pushSetting: pushSetting)
    }
}

extension DoNotDisturbViewController: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return 7
    }
}

extension DoNotDisturbViewController: UIPickerViewDelegate {
    
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        var componentText: String? = nil
        switch row {
        case PeriodOffTime.time1Hour.rawValue:
            componentText = NSLocalizedString("doNotDisturb_onPeriod_1Hour", comment: "")
        case PeriodOffTime.time2Hours.rawValue:
            componentText = NSLocalizedString("doNotDisturb_onPeriod_2Hours", comment: "")
        case PeriodOffTime.time3Hours.rawValue:
            componentText = NSLocalizedString("doNotDisturb_onPeriod_3Hours", comment: "")
        case PeriodOffTime.time4Hours.rawValue:
            componentText = NSLocalizedString("doNotDisturb_onPeriod_4Hours", comment: "")
        case PeriodOffTime.time8Hours.rawValue:
            componentText = NSLocalizedString("doNotDisturb_onPeriod_8Hours", comment: "")
        case PeriodOffTime.time1Day.rawValue:
            componentText = NSLocalizedString("doNotDisturb_onPeriod_1day", comment: "")
        case PeriodOffTime.time1Week.rawValue:
            componentText = NSLocalizedString("doNotDisturb_onPeriod_1week", comment: "")
        default:
            return nil
        }
        
        return NSAttributedString.init(string: componentText!, attributes: [.foregroundColor : Colors.fontNormal()!])
    }

    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        pushSetting.periodOffTime = PeriodOffTime(rawValue: row)!
        switch pushSetting.periodOffTime.rawValue {
        case PeriodOffTime.time1Hour.rawValue:
            pushSetting.periodOffTillDate = Calendar.current.date(byAdding: .hour,  value: 1, to: Date.init())
            break
        case PeriodOffTime.time2Hours.rawValue:
            pushSetting.periodOffTillDate = Calendar.current.date(byAdding: .hour,  value: 2, to: Date.init())
            break
        case PeriodOffTime.time3Hours.rawValue:
            pushSetting.periodOffTillDate = Calendar.current.date(byAdding: .hour,  value: 3, to: Date.init())
            break
        case PeriodOffTime.time4Hours.rawValue:
            pushSetting.periodOffTillDate = Calendar.current.date(byAdding: .hour,  value: 4, to: Date.init())
            break
        case PeriodOffTime.time8Hours.rawValue:
            pushSetting.periodOffTillDate = Calendar.current.date(byAdding: .hour,  value: 8, to: Date.init())
            break
        case PeriodOffTime.time1Day.rawValue:
            pushSetting.periodOffTillDate = Calendar.current.date(byAdding: .day,  value: 1, to: Date.init())
            break
        case PeriodOffTime.time1Week.rawValue:
            pushSetting.periodOffTillDate = Calendar.current.date(byAdding: .weekOfMonth,  value: 1, to: Date.init())
            break
        default:
            break
        }

        delegate?.pushSettingChanged(pushSetting: pushSetting)
    }
}
