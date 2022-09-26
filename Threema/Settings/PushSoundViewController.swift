//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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

import AudioToolbox
import CocoaLumberjackSwift
import Foundation
import UIKit

class PushSoundViewController: ThemedTableViewController {
    var isGroup = false
    private let pushSounds: [String] = PushSounds.all
    
    private var selectedIndexPath: IndexPath?
    private var businessInjector = BusinessInjector()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if isGroup {
            navigationItem.title = BundleUtil.localizedString(forKey: "push_group_sound_title")
        }
        else {
            navigationItem.title = BundleUtil.localizedString(forKey: "push_sound_title")
        }
    }
    
    // MARK: - Push sound info & play

    private var currentPushSound: String {
        if isGroup {
            return businessInjector.userSettings.pushGroupSound
        }
        else {
            return businessInjector.userSettings.pushSound
        }
    }
    
    func playPushSound(withName name: String) {
        guard name != "none" else {
            return
        }
        guard name != "default" else {
            AudioServicesPlayAlertSound(1007)
            return
        }
        guard let soundPath = BundleUtil.path(forResource: name, ofType: "caf") else {
            DDLogError("Unable to load sound file path for `\(name)`")
            return
        }
        
        let soundFileURL = URL(fileURLWithPath: soundPath)
        var soundID: SystemSoundID = 0
        func soundCompletionCallback(soundID: SystemSoundID, _: UnsafeMutableRawPointer?) {
            AudioServicesRemoveSystemSoundCompletion(soundID)
            AudioServicesDisposeSystemSoundID(soundID)
        }
        
        AudioServicesCreateSystemSoundID(soundFileURL as CFURL, &soundID)
        AudioServicesAddSystemSoundCompletion(soundID, nil, nil, soundCompletionCallback, nil)
        AudioServicesPlayAlertSound(soundID)
    }
}

// MARK: - UITableViewDataSource

extension PushSoundViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        pushSounds.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SoundCell", for: indexPath)
        let soundName = pushSounds[indexPath.row]
        let soundNameLocalizationKey = "sound_\(soundName)"
        cell.textLabel?.text = BundleUtil.localizedString(forKey: soundNameLocalizationKey)
        
        if currentPushSound == soundName {
            selectedIndexPath = indexPath
            cell.accessoryType = .checkmark
        }
        else {
            cell.accessoryType = .none
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension PushSoundViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isGroup {
            businessInjector.userSettings.pushGroupSound = pushSounds[indexPath.row]
        }
        else {
            businessInjector.userSettings.pushSound = pushSounds[indexPath.row]
        }
        playPushSound(withName: pushSounds[indexPath.row])
        
        if let selected = selectedIndexPath {
            tableView.cellForRow(at: selected)?.accessoryType = .none
        }
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
        tableView.deselectRow(at: indexPath, animated: true)
        selectedIndexPath = indexPath
    }
}
