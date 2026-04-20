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
