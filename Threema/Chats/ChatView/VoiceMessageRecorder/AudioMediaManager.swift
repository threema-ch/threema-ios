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
import CocoaLumberjackSwift

class AudioMediaManager: AudioMediaManagerProtocol {
    static func cleanupFiles(_ urls: [URL]) {
        DispatchQueue.global(qos: .background).async {
            try? urls.deleteItems()
        }
    }
    
    static func tmpAudioURL(with namedFile: String) -> URL {
        let fullFileName = "\(namedFile)-\(DateFormatter.getDateForExport(.now))"
        let tmpDir = FileManager.default.temporaryDirectory
        let url = tmpDir.appendingPathComponent(fullFileName).appendingPathExtension(MEDIA_EXTENSION_AUDIO)

        DDLogInfo("fileURL: \(url)")
        return url
    }
    
    static func moveToPersistentDir(from url: URL) -> Result<URL, VoiceMessageError> {
        guard let persistentDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else {
            return .failure(.fileOperationFailed)
        }
        return moveFile(
            from: url,
            to: persistentDir
                .appendingPathComponent(url.lastPathComponent)
        )
    }
    
    private static func moveFile(from url: URL, to newURL: URL) -> Result<URL, VoiceMessageError> {
        do {
            if FileManager.default.fileExists(atPath: newURL.path) {
                return .success(newURL)
            }
            
            try FileManager.default.moveItem(at: url, to: newURL)
            DDLogInfo("Moved file from: \(url.path) to: \(newURL.path)")
            return .success(newURL)
        }
        catch {
            DDLogError("Error occurred moving file: \(error.localizedDescription)")
            return .failure(.fileOperationFailed)
        }
    }
    
    static func concatenateRecordingsAndSave(
        combine urls: [URL],
        to audioFile: URL
    ) async -> Result<Void, VoiceMessageError> {
        let composition = AVMutableComposition()
        do {
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
            return await save(composition, to: audioFile)
        }
        catch {
            DDLogError("Error occurred saving : \(error.localizedDescription)")
            return .failure(.couldNotSave)
        }
    }
    
    static func save(_ asset: AVAsset, to url: URL) async -> Result<Void, VoiceMessageError> {
        // remove old file
        try? url.deleteItem()
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            return .failure(.assetNotFound)
        }
        
        exportSession.outputURL = url
        exportSession.outputFileType = .m4a
        exportSession.shouldOptimizeForNetworkUse = true
        await exportSession.export()
        DDLogInfo("ExportSession: \(url.absoluteString), status: \(String(describing: exportSession.status))")
        return exportSession.status != .completed ? .failure(.exportFailed) : .success(())
    }
}
