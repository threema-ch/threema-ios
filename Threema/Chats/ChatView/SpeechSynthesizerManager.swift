//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
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

/// For the text to speech function. The audio session is handled by the class itself.
class SpeechSynthesizerManager: NSObject {
    private lazy var synth = {
        let speechSynthesizer = AVSpeechSynthesizer()
        speechSynthesizer.delegate = self
        return speechSynthesizer
    }()
    
    private var prevAudioSessionCategory: AVAudioSession.Category?
    private var currentUtterance: AVSpeechUtterance?
        
    func speak(_ text: String) {
        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
            currentUtterance = nil
        }
        
        setupAudioSession()
        
        let utterance = AVSpeechUtterance(string: text)
        synth.speak(utterance)

        currentUtterance = utterance
    }
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        if prevAudioSessionCategory == nil {
            prevAudioSessionCategory = audioSession.category
        }
        do {
            try audioSession.setCategory(
                .playback,
                mode: .voicePrompt
            )
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        }
        catch {
            DDLogError("SpeechSynthesizerManager can't set audio session category \(error.localizedDescription)")
        }
    }
    
    private func resetAudioSession() {
        if let prevAudioSessionCategory {
            let audioSession = AVAudioSession.sharedInstance()

            do {
                try audioSession.setCategory(
                    prevAudioSessionCategory
                )
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            }
            catch {
                DDLogError("SpeechSynthesizerManager can't set audio session category \(error.localizedDescription)")
            }
            self.prevAudioSessionCategory = nil
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechSynthesizerManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if currentUtterance == utterance {
            currentUtterance = nil
            resetAudioSession()
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        if currentUtterance == utterance {
            currentUtterance = nil
            resetAudioSession()
        }
    }
}
