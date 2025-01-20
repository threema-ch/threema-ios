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

import Combine
import Foundation
import ThreemaFramework

enum SessionState {
    case background
    case closed(audioFile: URL)
}

protocol VoiceMessageManagerProtocolBase: Actor {
    associatedtype DraftStore: MessageDraftStoreProtocol
    associatedtype MediaManager: AudioMediaManagerProtocol
    
    var delegate: VoiceMessageAudioRecorderDelegate? { get set }
    
    nonisolated var recordingStates: AnyPublisher<RecordingState, Never> { get }
    nonisolated var recordingStateSubject: PassthroughSubject<RecordingState, Never> { get }
    
    var audioSessionManager: AudioSessionManagerProtocol { get }
    
    var interrupted: Bool { get }
    var isRecording: Bool { get }
    var isPlaying: Bool { get }
    var lastAveragePower: Float { get }
    var tmpAudioDuration: TimeInterval { get }
    var sufficientLength: Bool { get }
    var recordedLength: TimeInterval { get }
        
    static func requestRecordPermission() async -> Bool
    
    func sendFile(for conversation: ConversationEntity) async
}

extension VoiceMessageManagerProtocolBase {
    static func requestRecordPermission() async -> Bool {
        if #available(iOS 17.0, *) {
            await AVAudioApplication.requestRecordPermission()
        }
        else {
            await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission {
                    continuation.resume(returning: $0)
                }
            }
        }
    }
    
    nonisolated static var proximityMonitoring: (activate: () -> Void, deactivate: () -> Void) {
        (
            activate: {
                Task { @MainActor in
                    UIDevice.current.isProximityMonitoringEnabled = !UserSettings.shared().disableProximityMonitoring
                }
            },
            deactivate: {
                Task { @MainActor in
                    UIDevice.current.isProximityMonitoringEnabled = false
                }
            }
        )
    }
    
    nonisolated static var idleTimer: (enable: () -> Void, disable: () -> Void) {
        (
            {
                Task { @MainActor in
                    UIApplication.shared.isIdleTimerDisabled = false
                }
            },
            {
                Task { @MainActor in
                    UIApplication.shared.isIdleTimerDisabled = true
                }
            }
        )
    }

    nonisolated static func resetIdleAndProximity() {
        if !NavigationBarPromptHandler.isWebActive {
            VoiceMessageRecorderActor.idleTimer.enable()
        }
        VoiceMessageRecorderActor.proximityMonitoring.deactivate()
    }
}

protocol AudioPlayerProtocol {
    func play() async
    func pause() async
    func playbackDidSeekTo(progress: Double) async
}

protocol AudioRecorderProtocol: Actor {
    func record()
    func stop()
}

protocol AudioRecorderSessionManager {
    func load(_ audioFile: URL?) async
    func savedSession(_ shouldMove: Bool) async throws -> SessionState
}

typealias VoiceMessageAudioRecorderProtocol = VoiceMessageManagerProtocolBase & AudioPlayerProtocol &
    AudioRecorderProtocol & AudioRecorderSessionManager
