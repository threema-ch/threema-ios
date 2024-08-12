//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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

// MARK: - VoiceMessageRecorderView.Model

extension VoiceMessageRecorderView {
    class Model: ObservableObject, @unchecked Sendable {
        @Published var recordingState: RecordingState

        @Published var samples: [Float] = []
        @Published var duration: TimeInterval = .zero
        @Published var configuration: Waveform.Configuration = .init(
            style: .striped(.init(color: .gray, width: 2, spacing: 1)),
            damping: .init(percentage: 0.0)
        )
        
        var voiceMessageManager: VoiceMessageAudioRecorder
        let shouldDrawSilence: Bool
        
        private let conversation: Conversation
        
        convenience init(conversation: Conversation, audioFile: URL? = nil) {
            let voiceMessageManager = VoiceMessageAudioRecorder()
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
            conversation: Conversation,
            voiceMessageManager: VoiceMessageAudioRecorder
        ) {
            self.recordingState = recordingState
            self.shouldDrawSilence = shouldDrawSilence
            self.conversation = conversation
            self.voiceMessageManager = voiceMessageManager
        }
        
        // MARK: - Recorder
        
        func record() {
            Task { await voiceMessageManager.record() }
        }
        
        func stop() {
            Task { await voiceMessageManager.stop() }
        }
   
        func send() {
            Task {
                await voiceMessageManager.sendFile(for: conversation)
            }
        }
        
        // MARK: - Player

        func seek(to progress: Double) {
            voiceMessageManager.playbackDidSeekTo(progress: progress)
        }
        
        func play() {
            if recordingState == .playing {
                voiceMessageManager.pause()
            }
            else {
                voiceMessageManager.play()
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
    func didUpdatePlayProgress(with recorder: VoiceMessageAudioRecorder, _ progress: Double) {
        duration = recorder.tmpAudioDuration * progress
    }
    
    func didUpdateRecordProgress(with recorder: VoiceMessageAudioRecorder, _ progress: Double) {
        duration = VoiceMessageAudioRecorder.Configuration.recordDuration.max * progress
        if recordingState.isRecording {
            samples.append(1 - pow(10, recorder.lastAveragePower / 30))
        }
    }
    
    func playerDidFinish() {
        recordingState = .paused
    }
    
    func handleError(_ error: some LocalizedError) {
        DDLogError("[Voice Recorder] Error during recording: \(error)")
        DispatchQueue.main.async {
            guard let error = error as? VoiceMessageError else {
                NotificationPresenterWrapper.shared.present(
                    type: .init(
                        notificationText: "voice_recorder_recording_error".localized,
                        notificationStyle: .error
                    ),
                    subtitle: "voice_recorder_error_message".localized
                )
                return
            }
            
            error.showAlert()
        }
    }
}
