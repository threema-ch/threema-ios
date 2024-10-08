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
import ThreemaFramework

class AudioMediaManager<FileUtil: FileUtilityProtocol>: AudioMediaManagerProtocol {
    static func concatenateRecordingsAndSave(
        combine urls: [URL],
        to audioFile: URL
    ) async throws {
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
        return try await save(composition, to: audioFile)
    }
    
    static func save(_ asset: AVAsset, to url: URL) async throws {
        // remove old file
        FileUtil.shared.delete(at: url)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw VoiceMessageError.assetNotFound
        }
        exportSession.outputURL = url
        exportSession.outputFileType = .m4a
        exportSession.shouldOptimizeForNetworkUse = true
        await exportSession.export()
        DDLogInfo("ExportSession: \(url.absoluteString), status: \(String(describing: exportSession.status))")
        if exportSession.status != .completed {
            throw VoiceMessageError.exportFailed
        }
    }
}
