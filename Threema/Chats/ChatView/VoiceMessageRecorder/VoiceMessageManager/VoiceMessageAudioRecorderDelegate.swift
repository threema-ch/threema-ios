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

import Foundation

protocol VoiceMessageAudioRecorderDelegate: AnyObject, Sendable {

    func playerDidFinish()
    
    /// Any Error that occurs during the recording/playback process.
    ///
    /// - Parameters:
    ///   - error: The error that occurred.
    func handleError(_ error: Error)
    
    /// Notifies the delegate that the recording progress has been updated.
    ///
    /// - Parameters:
    ///   - lastAveragePower: The last average power of the current recording..
    ///   - progress: The current record progress as a `Double` representing the percentage of completion.
    @MainActor func didUpdateRecordProgress(lastAveragePower: Float, _ progress: Double)
    
    /// Notifies the delegate that the playback progress has been updated.
    ///
    /// - Parameters:
    ///   - duration: The current record duration as a `Double` representing the timestamp of the current playback.
    @MainActor func didUpdatePlayProgress(duration: Double)
}
