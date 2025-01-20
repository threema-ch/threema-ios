//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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

final class SoundPreviewPlayer {
    private var audioPlayer: AVAudioPlayer?
    
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground(application:)),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    deinit {
        audioPlayer?.stop()
        
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    @objc private func applicationDidEnterBackground(application: UIApplication) {
        audioPlayer?.stop()
    }
    
    func playVoIPSound(voIPSoundName: String) {
        
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
    
    func stopPlaying() {
        audioPlayer?.stop()
    }
}
