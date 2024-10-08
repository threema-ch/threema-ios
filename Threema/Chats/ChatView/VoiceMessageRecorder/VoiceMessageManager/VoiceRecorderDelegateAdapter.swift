//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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

// MARK: - VoiceMessageRecorderActor.DelegateAdapter

extension VoiceMessageRecorderActor {
    class DelegateAdapter: NSObject {
        typealias Block = () async -> Void
        private let didFinishPlayback: Block
        private let didFinishRecording: Block
        init(
            didFinishPlayback: @escaping Block,
            didFinishRecording: @escaping Block
        ) {
            self.didFinishPlayback = didFinishPlayback
            self.didFinishRecording = didFinishRecording
        }
    }
}

// MARK: - VoiceMessageRecorderActor.DelegateAdapter + AVAudioPlayerDelegate

extension VoiceMessageRecorderActor.DelegateAdapter: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { await didFinishPlayback() }
    }
}

// MARK: - VoiceMessageRecorderActor.DelegateAdapter + AVAudioRecorderDelegate

extension VoiceMessageRecorderActor.DelegateAdapter: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { await didFinishRecording() }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        DDLogError("Encode error: \(error ?? "Unknown error occurred")")
    }
}

extension VoiceMessageRecorderActor {
    func didFinishRecording() {
        if interrupted {
            interrupted = false
        }
        else {
            Task {
                await stop()
            }
        }
    }
    
    func didFinishPlayback() {
        Task { @MainActor in
            delegate?.playerDidFinish()
            stopTimer()
        }
        
        guard let port = audioSessionManager.currentRoute.outputs.first?.portType else {
            return
        }
        switch port {
        case .builtInSpeaker:
            audioSessionManager.setupAudioSession(isEarpiece: false)
        case .builtInReceiver:
            audioSessionManager.setupAudioSession(isEarpiece: true)
        default:
            break
        }
    }
}
