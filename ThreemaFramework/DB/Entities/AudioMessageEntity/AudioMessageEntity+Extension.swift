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
import ThreemaMacros

extension AudioMessageEntity {
    
    override public func additionalExportInfo() -> String? {
        var seconds = duration.intValue
        let minutes: Int = seconds / 60
        seconds = seconds - minutes * 60
        return "\(#localize("file_message_voice")) (\(minutes):\(seconds),\(blobFilename ?? "nil")"
    }
    
    #if !DEBUG
        override public var debugDescription: String {
            "<\(type(of: self))>:\(AudioMessageEntity.self), audioBlobId = \("***"), audioSize = \(audioSize?.description ?? "nil"), duration = \(duration.description), encryptionKey = \("***"), progress = \(progress?.description ?? "nil"), audio = \(audio?.description ?? "nil")"
        }
    #endif
}
