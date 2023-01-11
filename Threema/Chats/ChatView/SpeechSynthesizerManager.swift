//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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

/// This exists to avoid an issue where `AVSpeechSynthesizer` wouldn't speak anything because it was immediately deallocated in iOS 16.0 and later after the function exits
@objc class SpeechSynthesizerManger: NSObject {
    private var synth: AVSpeechSynthesizer?
    
    @objc func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        synth = AVSpeechSynthesizer()
        synth?.delegate = self
        synth?.speak(utterance)
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechSynthesizerManger: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        synth = nil
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        synth = nil
    }
}
