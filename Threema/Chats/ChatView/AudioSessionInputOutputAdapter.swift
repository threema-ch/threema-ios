import CocoaLumberjackSwift
import Foundation

enum AudioSessionInputOutputAdapter {
    static func proximityStateChanged(for audioPlayer: AVAudioPlayer?, onError: ((NSError) -> Void)? = nil) {
        let currentRoute = AVAudioSession.sharedInstance().currentRoute
        if !currentRoute.outputs.isEmpty, let audioPlayer, audioPlayer.isPlaying,
           let firstOutput = currentRoute.outputs.first,
           firstOutput.portType == .builtInSpeaker || firstOutput.portType == .builtInReceiver {
            AudioSessionInputOutputAdapter.adaptToProximityState(for: currentRoute, onError: onError)
        }
    }
    
    static func adaptToProximityState() {
        adaptToProximityState(for: AVAudioSession.sharedInstance().currentRoute, onError: nil)
    }
    
    private static func adaptToProximityState(
        for currentRoute: AVAudioSessionRouteDescription,
        onError: ((NSError) -> Void)?
    ) {
        guard !currentRoute.outputs.isEmpty else {
            AudioSessionInputOutputAdapter.setupAudioSession(forEarpiece: false, onError: onError)
            return
        }
        
        guard let firstOutput = currentRoute.outputs.first,
              firstOutput.portType == .builtInSpeaker || firstOutput.portType == .builtInReceiver else {
            AudioSessionInputOutputAdapter.setupAudioSession(forEarpiece: false, onError: onError)
            return
        }
        
        guard UIDevice.current.proximityState else {
            AudioSessionInputOutputAdapter.setupAudioSession(forEarpiece: false, onError: onError)
            return
        }
        
        AudioSessionInputOutputAdapter.setupAudioSession(forEarpiece: true, onError: onError)
    }
    
    private static func setupAudioSession(forEarpiece: Bool, onError: ((NSError) -> Void)?) {
        guard VoIPCallStateManager.shared.currentCallState() == .idle,
              !NavigationBarPromptHandler.isGroupCallActive else {
            return
        }
        
        let session = AVAudioSession.sharedInstance()
        
        do {
            if forEarpiece {
                try session.setCategory(.playAndRecord, options: [.allowBluetooth, .allowBluetoothA2DP])
                try session.setMode(.spokenAudio)
            }
            else {
                try session.setCategory(.playback, options: [])
                try session.setMode(.spokenAudio)
            }
        }
        catch {
            let err = error as NSError
            
            let errCode = err.code
            let errDescription = err.localizedDescription
            let errReason = String(describing: err.localizedFailureReason)
            let msg =
                "Cannot set audio session override output audio port due to an error with code \(errCode) description \(errDescription) and \(errReason)"
            
            DDLogError("\(msg)")
            debugPrintInAndOutputs()
            
            onError?(err)
        }
        
        do {
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        }
        catch {
            DDLogError("Could not set audio session to active because an error occurred \(error.localizedDescription)")
            debugPrintInAndOutputs()
        }
    }
    
    private static func debugPrintInAndOutputs() {
        if let availableInputs = AVAudioSession.sharedInstance().availableInputs {
            for input in availableInputs {
                DDLogInfo("Play/Record audio: Available input port: \(input.portType)")
            }
        }
        else {
            DDLogInfo("Play/Record audio: No input types available")
        }
        
        let availableOutputs = AVAudioSession.sharedInstance().currentRoute.outputs
        for output in availableOutputs {
            DDLogInfo("Play/Record audio: Current output port: \(output.portType)")
        }
    }
    
    static func currentAudioSession() -> AVAudioSession.Category {
        AVAudioSession.sharedInstance().category
    }
    
    static func resetAudioSession(to category: AVAudioSession.Category?) {
        guard VoIPCallStateManager.shared.currentCallState() == .idle,
              !NavigationBarPromptHandler.isGroupCallActive else {
            return
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            if let category {
                try audioSession.setCategory(category)
            }
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        }
        catch {
            DDLogError("Could not reset audio session due to an error: \(error.localizedDescription)")
        }
    }
}
