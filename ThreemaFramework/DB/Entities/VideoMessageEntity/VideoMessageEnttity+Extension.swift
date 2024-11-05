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

extension VideoMessageEntity {
    override public func additionalExportInfo() -> String? {
        var seconds = duration.intValue
        let minutes: Int = seconds / 60
        seconds = seconds - minutes * 60
        return "\(#localize("video")) (\(minutes):\(seconds),\(blobFilename ?? "nil")"
    }
    
    #if !DEBUG
        override public var debugDescription: String {
            "<\(type(of: self))>:\(VideoMessageEntity.self), progress = \(progress?.description ?? "nil"), videoBlobId = \("***"), encryptionKey = \("***"), videoSize = \(videoSize?.description ?? "nil"), video = \(video?.description ?? "nil"), thumbnail = \(thumbnail?.description ?? "nil"), duration = \(duration.description)"
        }
    #endif
}
