//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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

import WebRTC

extension RTCCallbackLogger {
    
    /// IOS-4113, SE-297
    /// Filters know error messages from WebRTC logs, so the log is not spammed with them.
    /// - Parameter message: Message to check for occurrences.
    /// - Returns: Message if know logs did not occur, `nil` otherwise.
    static func trimMessage(message: String) -> String? {
        if message.contains("Failed to demux RTP packet") ||
            message
            .contains(
                "Another unsignalled ssrc packet arrived shortly after the creation of an unsignalled ssrc stream"
            ) {
            return nil
        }
        
        return message.trimmingCharacters(in: .newlines)
    }
}
