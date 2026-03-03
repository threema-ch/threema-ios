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

final class AudioSessionManager: AudioSessionManagerProtocol {
    let session = AVAudioSession.sharedInstance()
    var prevAudioSessionCategory: AVAudioSession.Category?
    
    init() {
        self.prevAudioSessionCategory = session.category
        adaptToProximityState()
    }
    
    deinit {
        resetAudioSession()
    }
    
    func setupForRecording() throws {
        try session.setActive(true)
        try session.setCategory(.playAndRecord, options: [.allowBluetooth, .allowBluetoothA2DP])
    }
    
    func setupForPlayback() throws {
        adaptToProximityState()
        try session.setActive(true)
    }
    
    private func resetAudioSession() {
        guard let prevAVCat = prevAudioSessionCategory else {
            assertionFailure()
            DDLogInfo("[Voice Recorder] AudioSession has already been reset")
            return
        }
        
        guard isCurrentCallIdleState, !NavigationBarPromptHandler.isGroupCallActive else {
            return
        }
    
        try? session.setCategory(prevAVCat)
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        prevAudioSessionCategory = nil
    }
    
    func adaptToProximityState() {
        let isClose = UIDevice.current.proximityState
        
        let outputs = session.currentRoute.outputs
        
        let usesBuiltInPortType = outputs.contains { $0.portType == .builtInSpeaker || $0.portType == .builtInReceiver }
        
        guard usesBuiltInPortType else {
            try? session.overrideOutputAudioPort(.none)
            return
        }
        
        if isClose {
            try? session.setCategory(.playAndRecord, options: [.allowBluetooth, .allowBluetoothA2DP])
            try? session.setMode(.spokenAudio)
        }
        else {
            try? session.setCategory(.playback, options: [])
            try? session.setMode(.spokenAudio)
        }
    }

    func setAmbientAudioActive(_ isActive: Bool) {
        guard isCurrentCallIdleState else {
            return
        }
        do {
            if isActive {
                try session.setCategory(.ambient, options: [])
                try session.setActive(true)
            }
            else {
                try session.setActive(false, options: .notifyOthersOnDeactivation)
            }
        }
        catch {
            DDLogError("Set audio session failed: \(error)")
        }
    }

    // MARK: - Helpers

    private var isCurrentCallIdleState: Bool {
        VoIPCallStateManager.shared.currentCallState() == .idle
    }
}
