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

import AVFoundation

@dynamicMemberLookup
protocol AudioSessionManagerProtocol: AnyObject {
    var session: AVAudioSession { get }
    var prevAudioSessionCategory: AVAudioSession.Category? { get set }
    
    @discardableResult
    func setupAudioSession(isEarpiece: Bool) -> Result<Void, AudioSessionError>
    @discardableResult
    func setupAudioSessionForPlayback() -> Result<Void, AudioSessionError>
    @discardableResult
    func setupForRecording() -> Result<Void, AudioSessionError>
    
    func resetAudioSession()
    
    func requestRecordPermission() async -> Bool
    
    subscript<T>(dynamicMember keyPath: KeyPath<AVAudioSession, T>) -> T { get }
}

extension AudioSessionManagerProtocol {
    /// Accesses the underlying `AVAudioSession` properties using dynamic member lookup.
    /// - Parameter keyPath: A key path to a specific property of the `AVAudioSession`.
    /// - Returns: The value of the property specified by the key path.
    subscript<T>(dynamicMember keyPath: KeyPath<AVAudioSession, T>) -> T { session[keyPath: keyPath] }
}

extension AudioSessionManagerProtocol {
    func requestRecordPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            session.requestRecordPermission { result in
                continuation.resume(returning: result)
            }
        }
    }
}
