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

import AVFoundation
import CocoaLumberjackSwift
import FileUtility
import ThreemaFramework

class AudioMediaManager: AudioMediaManagerProtocol {

    static func newRecordingAudioURL() -> URL {
        let fullFileName = "voice_recording_\(DateFormatter.getDateForExport(.now))"
        let url = FileUtility.shared.appTemporaryUnencryptedDirectory
            .appendingPathComponent(fullFileName)
            .appendingPathExtension(MEDIA_EXTENSION_AUDIO)

        DDLogInfo("[Voice Recorder] New audio url: \(url)")
        return url
    }

    static func cleanupFile(_ url: URL) {
        Task(priority: .background) {
            FileUtility.shared.deleteIfExists(at: url)
        }
    }

    static func concatenateRecordingsAndSave(
        combine urls: [URL],
        to audioFile: URL,
        completion: @escaping () -> Void
    ) throws -> AVAsset {
        let composition = AVMutableComposition()
        
        for url in urls {
            let asset = AVURLAsset(url: url)
        
            if let track = asset.tracks(withMediaType: .audio).first {
                let timeRange = CMTimeRange(start: .zero, duration: asset.duration)
                
                if let compositionTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                ) {
                    try compositionTrack.insertTimeRange(timeRange, of: track, at: composition.duration)
                }
            }
        }
        
        // Remove combined files
        for url in urls {
            FileUtility.shared.deleteIfExists(at: url)
        }
        
        Task {
            try await save(composition, to: audioFile)
            completion()
        }
            
        return composition
    }

    static func copy(source: URL, destination: URL) throws {
        do {
            try FileUtility.shared.copy(from: source, to: destination)
        }
        catch {
            throw VoiceMessageError.fileOperationFailed
        }
    }

    static func moveToDocumentsDir(from url: URL) throws -> URL {
        guard let persistentDir = FileUtility.shared.appDocumentsDirectory
        else {
            throw VoiceMessageError.fileOperationFailed
        }

        let newURL = persistentDir.appendingPathComponent(url.lastPathComponent)

        do {
            if !FileUtility.shared.fileExists(at: newURL) {
                try FileUtility.shared.move(from: url, to: newURL)
            }
        }
        catch {
            throw VoiceMessageError.fileOperationFailed
        }

        return newURL
    }

    // MARK: - Private functions

    private static func save(_ asset: AVAsset, to url: URL) async throws {
        // Remove old file
        FileUtility.shared.deleteIfExists(at: url)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw VoiceMessageError.assetNotFound
        }
        exportSession.outputURL = url
        exportSession.outputFileType = .m4a
        exportSession.shouldOptimizeForNetworkUse = true
        
        await exportSession.export()

        if exportSession.status != .completed {
            assertionFailure()
            DDLogError(
                "[Voice Recorder] ExportSession: \(url.absoluteString), status: \(String(describing: exportSession.status))"
            )
            throw VoiceMessageError.exportFailed
        }
    }
}
