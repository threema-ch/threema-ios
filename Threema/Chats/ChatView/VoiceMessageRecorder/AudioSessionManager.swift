//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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

import AVFoundation
import CocoaLumberjackSwift

enum AudioSessionError: Equatable, LocalizedError {
    case couldNotActivateCategory
    case callStateNotIdle
    case error(NSError)
    
    var localizedDescription: String {
        switch self {
        case .couldNotActivateCategory:
            "Could not activate audio session category"
        case .callStateNotIdle:
            "Call state is not idle"
        case let .error(error):
            error.localizedDescription
        }
    }
}

final class AudioSessionManager: AudioSessionManagerProtocol {
    let session = AVAudioSession.sharedInstance()
    var prevAudioSessionCategory: AVAudioSession.Category?
    
    init() {
        self.prevAudioSessionCategory = session.category
    }
    
    deinit {
        resetAudioSession()
    }
    
    /// Sets up the audio session for recording.
    /// It activates the audio session and sets the category to `.playAndRecord` with the mode set to `.default`.
    /// It also allows Bluetooth options for the audio session.
    /// - Returns: A `Result` indicating success or an `AudioSessionError`.
    @discardableResult func setupForRecording() -> Result<Void, AudioSessionError> {
        do {
            try session.setActive(true)
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.allowBluetooth, .allowBluetoothA2DP])
            // VoiceOver is included in VoiceMessages, maybe not the best solution
            if session.currentRoute.outputs.filter({ $0.portType == .headphones }).isEmpty {
                try session.overrideOutputAudioPort(.none)
            }
            
            return .success(())
        }
        catch let error as NSError {
            DDLogError("\(error.localizedDescription)")
            return .failure(.couldNotActivateCategory)
        }
    }
    
    /// Sets up the audio session for playback.
    /// It activates the audio session and sets the category to `.playback` with the mode set to `.spokenAudio`.
    /// - Returns: A `Result` indicating success or an `AudioSessionError`.
    @discardableResult func setupAudioSessionForPlayback() -> Result<Void, AudioSessionError> {
        do {
            try session.setCategory(.playback)
            try session.setMode(.spokenAudio)
            try session.setActive(true)
            
            return .success(())
        }
        catch let error as NSError {
            DDLogError("\(error.localizedDescription)")
            return .failure(.couldNotActivateCategory)
        }
    }
    
    /// Configures the audio session for either earpiece or speaker playback.
    /// - Parameter isEarpiece: A Boolean value indicating whether the audio session should be set up for earpiece
    /// playback.
    /// - Returns: A `Result` indicating whether the audio session was successfully set up or an `AudioSessionError` if
    /// an error occurred.
    @discardableResult func setupAudioSession(isEarpiece: Bool) -> Result<Void, AudioSessionError> {
        guard VoIPCallStateManager.shared.currentCallState() == .idle,
              !NavigationBarPromptHandler.isGroupCallActive else {
            return .failure(.callStateNotIdle)
        }
        
        do {
            if isEarpiece {
                try session.overrideOutputAudioPort(.none)
            }
            
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            
            printInAndOutputs()
            return .success(())
        }
        catch let error as NSError {
            DDLogError("\(error.localizedDescription)")
            return .failure(.error(error))
        }
    }
    
    /// Resets the audio session to its previous category if it has been changed.
    /// This function will do nothing if the audio session is already reset or if there is an ongoing call.
    func resetAudioSession() {
        guard let prevAVCat = prevAudioSessionCategory else {
            DDLogInfo("AudioSession has already been reset")
            return
        }
        
        guard VoIPCallStateManager.shared.currentCallState() == .idle,
              !NavigationBarPromptHandler.isGroupCallActive else {
            return
        }
    
        try? session.setCategory(prevAVCat)
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        prevAudioSessionCategory = nil
    }
    
    func adaptToProximityState(isPlaying: Bool) {
        guard let output = session.currentRoute.outputs.first,
              isPlaying, [.builtInSpeaker, .builtInReceiver].contains(output.portType)
        else {
            setupAudioSession(isEarpiece: false)
            return
        }
        Task { @MainActor in
            setupAudioSession(isEarpiece: UIDevice.current.proximityState)
        }
    }

    private func printInAndOutputs() {
        session.availableInputs?.forEach {
            DDLogInfo("Play/Record audio: Available input port: \($0.portType)")
        }
        
        for output in session.currentRoute.outputs {
            DDLogInfo("Play/Record audio: Current output port: \(output.portType)")
        }
    }
}
