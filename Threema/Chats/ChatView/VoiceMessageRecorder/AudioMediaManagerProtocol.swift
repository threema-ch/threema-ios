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

import CocoaLumberjackSwift
import Foundation
import ThreemaFramework

protocol AudioMediaManagerProtocol: AnyObject {
    associatedtype FileUtil: FileUtilityProtocol
    
    static func audioURL() -> URL
    static func concatenateRecordingsAndSave(
        combine urls: [URL],
        to audioFile: URL,
        completion: @escaping () -> Void
    ) async throws -> AVAsset
    
    static func moveToPersistentDir(from url: URL) throws -> URL
    static func copy(source: URL, destination: URL) throws
    static func cleanupFiles(_ urls: URL)
}

extension AudioMediaManager {
    static func cleanupFiles(_ url: URL) {
        Task(priority: .background) {
            FileUtil.shared.delete(at: url)
        }
    }
    
    static func audioURL() -> URL {
        let fullFileName = "voice_recording_\(DateFormatter.getDateForExport(.now))"
        let url = FileUtil.shared.appTemporaryDirectory
            .appendingPathComponent(fullFileName)
            .appendingPathExtension(MEDIA_EXTENSION_AUDIO)

        DDLogInfo("[Voice Recorder] New audio url: \(url)")
        return url
    }
    
    static func playAudioURL() -> URL {
        let fullFileName = "voice_play_\(DateFormatter.getDateForExport(.now))"
        let url = FileUtil.shared.appTemporaryDirectory
            .appendingPathComponent(fullFileName)
            .appendingPathExtension(MEDIA_EXTENSION_AUDIO)

        DDLogInfo("[Voice Recorder] New play url: \(url)")
        return url
    }

    static func copy(source: URL, destination: URL) throws {
        guard FileUtil.shared.copy(source: source, destination: destination) else {
            throw VoiceMessageError.fileOperationFailed
        }
    }
    
    static func moveToPersistentDir(from url: URL) throws -> URL {
        guard let persistentDir = FileUtil.shared.appDocumentsDirectory
        else {
            throw VoiceMessageError.fileOperationFailed
        }
        return try moveFile(
            from: url,
            to: persistentDir
                .appendingPathComponent(url.lastPathComponent)
        )
    }
    
    private static func moveFile(from url: URL, to newURL: URL) throws -> URL {
        guard !FileUtil.shared.isExists(fileURL: newURL) else {
            return newURL
        }
        guard FileUtil.shared.move(source: url, destination: newURL) else {
            throw VoiceMessageError.fileOperationFailed
        }
        return newURL
    }
}
