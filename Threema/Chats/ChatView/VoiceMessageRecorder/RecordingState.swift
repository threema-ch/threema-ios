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

import Foundation

/// States of a recording session.
enum RecordingState {
    /// No recording is currently active.
    case none
    
    // MARK: - Recording
    
    /// Recording is currently in progress.
    case recording
    /// Recording has been stopped.
    case stopped
    
    // MARK: - Playback
    
    /// Playback of a recording is currently in progress.
    case playing
    /// Playback of a recording is paused.
    case paused
    
    /// Indicating whether the recording has been stopped, either explicitly or by pausing or ending playback.
    var isRecordingStopped: Bool {
        switch self {
        case .paused, .playing, .stopped:
            return true
        default:
            return false
        }
    }
}
