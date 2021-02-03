//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2021 Threema GmbH
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

class NotificationSettingViewController: ThemedTableViewController {
    
    @objc var isGroup: Bool = false
    @objc var identity: String?
    @objc var conversation: Conversation?
    private var _pushSetting:PushSetting?
    private var _pushSettingList: NSMutableOrderedSet?
    
    @IBOutlet weak var doNotDisturbCell: DoNotDisturbCell!
    @IBOutlet weak var mentionsCell: UITableViewCell!
    @IBOutlet weak var soundCell: UITableViewCell!
    @IBOutlet weak var soundSwitch: UISwitch!
    @IBOutlet weak var mentionsSwitch: UISwitch!
    @IBOutlet weak var masterDndView: UIView!
    @IBOutlet weak var masterDndInfoLabel: UILabel!
    @IBOutlet weak var masterDndInfoImageView: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(colorThemeChanged(notification:)), name: NSNotification.Name(rawValue: kNotificationColorThemeChanged), object: nil)
        
        _pushSettingList = NSMutableOrderedSet.init(orderedSet: UserSettings.shared().pushSettingsList)
        _pushSetting = PushSetting.find(forIdentity: identity)
        if _pushSetting == nil {
            _pushSetting = PushSetting()
            _pushSetting!.identity = identity
            _pushSetting!.type = .on
            _pushSetting!.silent = false
            _pushSetting!.mentions = false
        } else {
            if _pushSetting!.type == .offPeriod {
                if _pushSetting!.periodOffTillDate != nil {
                    if _pushSetting!.periodOffTillDate < Date() {
                        _pushSetting!.type = .on
                    }
                } else {
                    _pushSetting!.type = .on
                }
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.title = NSLocalizedString("pushSetting_title", comment: "")
        
        self.setup()
        tableView.reloadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if self.isMovingFromParent {
            save()
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowDoNotDisturb" {
            let controller = segue.destination as! DoNotDisturbViewController
            controller.delegate = self
            controller.pushSetting = _pushSetting
        }
    }
    
    private func setup() {
        soundSwitch.setOn(!_pushSetting!.silent, animated: false)
        mentionsSwitch.setOn(_pushSetting!.mentions, animated: false)
        
        doNotDisturbCell.titleLabel?.text = BundleUtil.localizedString(forKey: "doNotDisturb_title")
        if _pushSetting!.type == .on {
            doNotDisturbCell.detailLabel?.text = BundleUtil.localizedString(forKey: "doNotDisturb_off")
        }
        else if _pushSetting!.type == .off {
            doNotDisturbCell.detailLabel?.text = BundleUtil.localizedString(forKey: "doNotDisturb_on")
        }
        else if _pushSetting!.type == .offPeriod {
            if _pushSetting!.periodOffTillDate != nil {
                doNotDisturbCell.detailLabel?.text = String.init(format: "%@ %@", BundleUtil.localizedString(forKey: "doNotDisturb_onPeriod_time"), DateFormatter.getFullDate(for: _pushSetting!.periodOffTillDate))
            } else {
                doNotDisturbCell.detailLabel?.text = NSLocalizedString("doNotDisturb_onPeriod", comment: "")
            }
        }
        
        mentionsCell.textLabel?.text = BundleUtil.localizedString(forKey: "doNotDisturb_mention")
        soundCell.textLabel?.text = BundleUtil.localizedString(forKey: "notification_sound_title")
        
        masterDndInfoImageView.image = BundleUtil.imageNamed("Info")?.withTint(Colors.fontNormal())
        masterDndInfoLabel.text = BundleUtil.localizedString(forKey: "settings_notifications_masterDnd_info")
        
        if UserSettings.shared().enableMasterDnd {
            self.tableView.tableHeaderView = masterDndView
        } else {
            self.tableView.tableHeaderView = nil
        }
        
        setupSoundCell()
    }
    
    private func setupSoundCell() {
        if (_pushSetting!.type == .off && !_pushSetting!.mentions && isGroup) ||
            _pushSetting!.type == .off && !isGroup {
            soundSwitch.isEnabled = false
            soundCell.textLabel?.isEnabled = false
        } else {
            soundSwitch.isEnabled = true
            soundCell.textLabel?.isEnabled = true
        }
    }
    
    private func save() {
        let setting = PushSetting.findDict(forIdentity: identity)
        if setting == nil {
            _pushSettingList!.add(_pushSetting!.buildDict()!)
            UserSettings.shared().pushSettingsList = _pushSettingList
        } else {
            _pushSettingList!.remove(setting as Any)
            _pushSettingList!.add(_pushSetting!.buildDict()!)
            UserSettings.shared().pushSettingsList = _pushSettingList
        }

        if conversation != nil {
            WCSessionManager.shared.updateConversationPushSetting(conversation: conversation!)
        }
    }
    
    
    // MARK: - Table view data source
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            if _pushSetting!.type == .on {
                return 1
            }
            else if _pushSetting!.type == .off {
                if isGroup {
                    return 2
                } else {
                    return 1
                }
            }
            else if _pushSetting!.type == .offPeriod {
                if isGroup {
                    return 2
                } else {
                    return 1
                }
            }
        }
        return super.tableView(tableView, numberOfRowsInSection: section)
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return NSLocalizedString("doNotDisturb_header", comment: "")
        } else {
            return NSLocalizedString("notification_sound_header", comment: "")
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if isGroup {
            if section == 0 && _pushSetting!.mentions && ( _pushSetting!.type == .off || _pushSetting!.type == .offPeriod) {
                return NSLocalizedString("doNotDisturb_mention_footer_on", comment: "")
            }
            else if section == 0 && !_pushSetting!.mentions && ( _pushSetting!.type == .off || _pushSetting!.type == .offPeriod) {
                return NSLocalizedString("doNotDisturb_mention_footer_off", comment: "")
            }
            else {
                return nil
            }
        }
        
        return nil
    }
    
    
    // MARK: - Actions
    
    @IBAction func soundSwitchChanged(sender: UISwitch) {
        _pushSetting!.silent = !sender.isOn
        save()
    }
    
    @IBAction func mentionsSwitchChanged(sender: UISwitch) {
        _pushSetting!.mentions = sender.isOn
        tableView.reloadData()
        save()
        setupSoundCell()
    }
    
    
    // MARK: - Notification
    
    @objc func colorThemeChanged(notification:NSNotification) {
        setup()
    }
}

extension NotificationSettingViewController: DoNotDisturbDelegate {
    func pushSettingChanged(pushSetting: PushSetting) {
        _pushSetting = pushSetting
        save()
        setupSoundCell()
    }
}
