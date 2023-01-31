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

import CocoaLumberjackSwift
import Foundation

class VoIPSoundViewController: ThemedTableViewController {
    
    private let voIPSounds = [
        "default",
        "threema_best",
        "threema_incom",
        "threema_xylo",
        "threema_goody",
        "threema_alphorn",
    ]
    private var audioPlayer: AVAudioPlayer?
    private var selectedIndexPath: IndexPath?
    private var businessInjector = BusinessInjector()
    
    // MARK: - Lifecycle
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        title = BundleUtil.localizedString(forKey: "settings_threema_calls_call_sound")
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground(application:)),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        audioPlayer?.stop()
        
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    // MARK: - UITableViewDataSource
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        voIPSounds.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCell(withIdentifier: "SoundCell", for: indexPath)
        let soundName = voIPSounds[indexPath.row]
        let soundNameLoccalizationKey = "sound_\(soundName)"
        
        cell.textLabel?.text = BundleUtil.localizedString(forKey: soundNameLoccalizationKey)
        
        if businessInjector.userSettings.voIPSound == soundName {
            selectedIndexPath = indexPath
            cell.accessoryType = .checkmark
        }
        else {
            cell.accessoryType = .none
        }
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        businessInjector.userSettings.voIPSound = voIPSounds[indexPath.row]
        
        playVoIPSound(voIPSoundName: voIPSounds[indexPath.row])
        
        if let selectedIndexPath = selectedIndexPath {
            tableView.cellForRow(at: selectedIndexPath)?.accessoryType = .none
        }
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
        tableView.deselectRow(at: indexPath, animated: true)
        selectedIndexPath = indexPath
    }
    
    // MARK: - Notifications
    
    @objc private func applicationDidEnterBackground(application: UIApplication) {
        audioPlayer?.stop()
    }
    
    // MARK: - Helper methods
    
    private func playVoIPSound(voIPSoundName: String) {
        
        guard voIPSoundName != "default" else {
            audioPlayer?.stop()
            return
        }
        
        guard let soundPath = BundleUtil.path(forResource: voIPSoundName, ofType: "caf") else {
            DDLogError("Unable to load sound file path for `\(voIPSoundName)`")
            audioPlayer?.stop()
            return
        }
        let soundURL = URL(fileURLWithPath: soundPath)
        
        if let audioplayer = audioPlayer {
            if audioplayer.url == soundURL {
                if audioplayer.isPlaying {
                    audioplayer.stop()
                }
                else {
                    audioplayer.currentTime = 0
                    audioplayer.play()
                }
                return
            }
            audioplayer.stop()
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.numberOfLoops = 2
            audioPlayer?.play()
        }
        catch {
            DDLogError("Unable to load audio player to play VoIP sound: \(error)")
        }
    }
}
