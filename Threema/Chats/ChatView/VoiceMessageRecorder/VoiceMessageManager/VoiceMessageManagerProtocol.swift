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

import Combine
import Foundation
import ThreemaFramework

enum VoiceMessageError: Equatable, LocalizedError {
    // Audio Session
    case audioSessionFailure
    case couldNotActivateCategory
    case callStateNotIdle
    case exportFailed
    // Audio Playback
    case audioFileMissing
    case playbackFailure
    // Audio Recording
    case noRecordPermission
    case recordingCancelled
    case assetNotFound
    case couldNotSave
    case recorderInitFailure
    // Generic Errors
    case error(NSError)
    case fileOperationFailed
    
    var failureReason: String? {
        switch self {
        case .recorderInitFailure:
            return "play_record_audio_view_controller_general_error_message".localized
            
        default:
            return nil
        }
    }
    
    var localizedDescription: String {
        switch self {
        case _:
            "play_record_audio_view_controller_general_error_title".localized
        }
    }
}

enum SessionState {
    case background
    case closed(audioFile: URL)
}

protocol VoiceMessageManagerProtocol: NSObject {
    associatedtype DraftStore: MessageDraftStoreProtocol
    associatedtype MediaManager: AudioMediaManagerProtocol
    
    var delegate: VoiceMessageAudioRecorderDelegate? { get set }
    
    var recordingStates: AnyPublisher<RecordingState, Never> { get }
    
    var audioSessionManager: AudioSessionManagerProtocol { get }
    
    var interrupted: Bool { get }
    var isRecording: Bool { get }
    var isPlaying: Bool { get }
    var lastAveragePower: Float { get }
    var tmpAudioDuration: TimeInterval { get }
    var sufficientLength: Bool { get }
    var recordedLength: TimeInterval { get }
        
    static func requestRecordPermission(_ handler: @escaping (Bool) -> Void)
    
    func sendFile(for conversation: Conversation) async
    func load(_ audioFile: URL?) async
    func savedSession(_ shouldMove: Bool) async throws -> SessionState
}

extension VoiceMessageManagerProtocol {
    static func requestRecordPermission(_ handler: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission {
            handler($0)
        }
    }
    
    static func requestRecordPermission() async -> Bool {
        if #available(iOS 17.0, *) {
            await AVAudioApplication.requestRecordPermission()
        }
        else {
            await withCheckedContinuation { continuation in
                requestRecordPermission { result in
                    continuation.resume(returning: result)
                }
            }
        }
    }
    
    var proximityMonitoring: (activate: () -> Void, deactivate: () -> Void) {
        (
            activate: {
                DispatchQueue.main.async {
                    if !UserSettings.shared().disableProximityMonitoring {
                        UIDevice.current.isProximityMonitoringEnabled = true
                    }
                }
            },
            deactivate: {
                DispatchQueue.main.async {
                    UIDevice.current.isProximityMonitoringEnabled = false
                }
            }
        )
    }
    
    var idleTimer: (enable: () -> Void, disable: () -> Void) {
        (
            {
                DispatchQueue.main.async {
                    UIApplication.shared.isIdleTimerDisabled = false
                }
            },
            {
                DispatchQueue.main.async {
                    UIApplication.shared.isIdleTimerDisabled = true
                }
            }
        )
    }
}

protocol AudioPlayerProtocol {
    func play()
    func pause()
    func playbackDidSeekTo(progress: Double)
}

protocol AudioRecorderProtocol {
    func record() async
    func stop() async
}

typealias VoiceMessageAudioRecorderProtocol = VoiceMessageManagerProtocol & AudioPlayerProtocol & AudioRecorderProtocol
