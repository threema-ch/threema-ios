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

import AVFoundation
import CocoaLumberjackSwift
import DSWaveformImage
import SwiftUI
import ThreemaFramework
import ThreemaMacros

// MARK: - VoiceMessageRecorderView.Model

extension VoiceMessageRecorderView {
    class Model: ObservableObject, @unchecked Sendable {
        @Published var recordingState: RecordingState

        @Published var samples: [Float] = []
        @Published var duration: TimeInterval = .zero
        @Published var configuration: Waveform.Configuration = .init(
            style: .striped(
                .init(
                    color: .gray,
                    width: 2,
                    spacing: 3
                )
            ),
            damping: .init(percentage: 0.1)
        )
        
        var voiceMessageManager: VoiceMessageRecorderActor
        let shouldDrawSilence: Bool
        
        private let conversation: ConversationEntity
        
        convenience init(conversation: ConversationEntity, audioFile: URL? = nil) {
            let voiceMessageManager = VoiceMessageRecorderActor()
            self.init(
                recordingState: .none,
                shouldDrawSilence: false,
                conversation: conversation,
                voiceMessageManager: voiceMessageManager
            )
            
            voiceMessageManager.recordingStates.assign(to: &$recordingState)
            voiceMessageManager.delegate = self
            
            Task {
                guard await voiceMessageManager.audioSessionManager.requestRecordPermission() else {
                    return
                }
                
                guard let audioFile else {
                    return await voiceMessageManager.load()
                }
                
                await voiceMessageManager.load(audioFile)
            }
        }
        
        private init(
            recordingState: RecordingState,
            shouldDrawSilence: Bool,
            conversation: ConversationEntity,
            voiceMessageManager: VoiceMessageRecorderActor
        ) {
            self.recordingState = recordingState
            self.shouldDrawSilence = shouldDrawSilence
            self.conversation = conversation
            self.voiceMessageManager = voiceMessageManager
        }
        
        // MARK: - Recorder
        
        func record() {
            Task(priority: .userInitiated) { await voiceMessageManager.record() }
        }
        
        func stop() {
            Task(priority: .userInitiated) { await voiceMessageManager.stop() }
        }
   
        func send() {
            Task(priority: .userInitiated) {
                await voiceMessageManager.sendFile(for: conversation)
            }
        }
        
        func willDismissView() {
            Task(priority: .userInitiated) {
                await voiceMessageManager.willDismissView()
            }
        }
        
        // MARK: - Player

        func seek(to progress: Double) {
            Task(priority: .userInitiated) {
                await voiceMessageManager.playbackDidSeekTo(progress: progress)
            }
        }
        
        func play() {
            Task(priority: .userInitiated) {
                if recordingState == .playing {
                    await voiceMessageManager.pause()
                }
                else {
                    await voiceMessageManager.play()
                }
            }
        }
        
        func loadSamples(count: Int) {
            Task {
                do {
                    let samples = try await WaveformAnalyzer().samples(
                        fromAudioAt: voiceMessageManager.tmpRecorderFile,
                        count: count
                    )
                    await MainActor.run {
                        self.samples = samples
                    }
                }
                catch let error as LocalizedError {
                    handleError(error)
                }
            }
        }
    }
}

// MARK: - VoiceMessageRecorderView.Model + VoiceMessageAudioRecorderDelegate

extension VoiceMessageRecorderView.Model: VoiceMessageAudioRecorderDelegate {
    @MainActor func didUpdatePlayProgress(duration: Double) {
        self.duration = duration
    }
    
    @MainActor func didUpdateRecordProgress(lastAveragePower: Float, _ progress: Double) {
        duration = VoiceMessageRecorderActor.Configuration.recordDuration.max * progress
        if recordingState.isRecording {
            let value = max(0.5, min(1, lastAveragePower))
            samples.append(value)
            samples.append(value)
            samples.append(value)
        }
    }
    
    @MainActor func playerDidFinish() {
        recordingState = .paused
    }
    
    func handleError(_ error: any Error) {
        
        if let error = error as? BlobManagerError, error == .noteGroupNeedsNoSync {
            return
        }
        
        DDLogError("[Voice Recorder] Error during recording: \(error)")
        DispatchQueue.main.async {
            guard let error = error as? VoiceMessageError else {
                NotificationPresenterWrapper.shared.present(
                    type: .init(
                        notificationText: #localize("voice_recorder_recording_error"),
                        notificationStyle: .error
                    ),
                    subtitle: #localize("voice_recorder_error_message")
                )
                return
            }
            
            error.showAlert()
        }
    }
}
