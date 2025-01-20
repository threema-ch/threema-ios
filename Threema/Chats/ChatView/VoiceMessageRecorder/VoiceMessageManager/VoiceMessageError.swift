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

import ThreemaFramework
import ThreemaMacros

enum VoiceMessageError: Equatable {
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
}

extension VoiceMessageError {
    func showAlert() {
        switch self {
        case .noRecordPermission:
            AppDelegate.shared().currentTopViewController().map {
                UIAlertTemplate.showOpenSettingsAlert(
                    owner: $0,
                    noAccessAlertType: .microphone,
                    openSettingsCompletion: nil
                )
            }
        default:
            NotificationPresenterWrapper.shared.present(
                type: .init(
                    notificationText: localizedDescription,
                    notificationStyle: self == .callStateNotIdle || self == .recordingCancelled ? .warning : .error
                ),
                subtitle: failureReason ?? ""
            )
        }
    }
}

// MARK: - LocalizedError

extension VoiceMessageError: LocalizedError {
    var failureReason: String? {
        switch self {
        case .callStateNotIdle:
            #localize("voice_recorder_call_state_not_idle_message")
        case .recordingCancelled:
            nil
        default:
            #localize("voice_recorder_error_message")
        }
    }

    var localizedDescription: String {
        switch self {
        case .callStateNotIdle:
            #localize("voice_recorder_call_state_not_idle")
        case .playbackFailure:
            #localize("voice_recorder_playback_failure")
        case .recordingCancelled:
            #localize("voice_recorder_recording_cancelled")
        default:
            #localize("voice_recorder_recording_error")
        }
    }
}
