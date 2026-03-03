//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

protocol AudioSessionManagerProtocol {
    var session: AVAudioSession { get }
    var prevAudioSessionCategory: AVAudioSession.Category? { get }

    func setupForPlayback() throws
    func setupForRecording() throws
    func adaptToProximityState()
    func setAmbientAudioActive(_ isActive: Bool)
}

extension AudioSessionManagerProtocol where Self == NullAudioSessionManager {
    static var null: Self { NullAudioSessionManager() }
}

struct NullAudioSessionManager: AudioSessionManagerProtocol {
    var session: AVAudioSession { .init() }
    var prevAudioSessionCategory: AVAudioSession.Category? { nil }

    func setupForPlayback() throws { /* no-op */ }
    func setupForRecording() throws { /* no-op */ }
    func adaptToProximityState() { /* no-op */ }
    func setAmbientAudioActive(_ isActive: Bool) { /* no-op */ }
}
