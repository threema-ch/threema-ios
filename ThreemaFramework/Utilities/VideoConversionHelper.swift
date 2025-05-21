//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2025 Threema GmbH
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

class VideoConversionHelper: NSObject {
    private let userSettings: UserSettingsProtocol

    // MARK: - Internal Nested Types
    
    enum VideoQualitySetting {
        case low
        case high
        case original
    }
    
    #if DEBUG
        init(userSettings: UserSettingsProtocol) {
            self.userSettings = userSettings
        }
    #endif
    
    @objc override init() {
        self.userSettings = UserSettings.shared()
    }

    /// The maximum duration for a video at the lowest possible quality in minutes.
    @objc public static var videoMaxDurationInMinutes: Double {
        let maxFileSizeInBits = Int32(kMaxFileSize * 8)

        /// Estimated file overhead for the video (same as in Android)
        /// Use for estimating final file size of the video
        let fileOverhead = Int32(48 * 1024)

        return Double((maxFileSizeInBits - fileOverhead) / ((kVideoBitrateLow + kAudioBitrateLow) * 60))
    }

    // MARK: - Functions
    
    @objc func videoHasAllowedSize(at url: URL) -> Bool {
        
        enum Video {
            static var allowed = false
        }

        let asset = AVURLAsset(url: url)
        
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            Video.allowed = await (getEstimatedVideoFileSize(for: asset) != nil)
            semaphore.signal()
        }
        
        semaphore.wait()

        return Video.allowed
    }
    
    func getEstimatedVideoFileSize(for url: URL) -> Double? {
        enum Video {
            static var size: Double? = nil
        }

        let asset = AVURLAsset(url: url)
        
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            Video.size = await getEstimatedVideoFileSize(for: asset)
            semaphore.signal()
        }
        
        semaphore.wait()
        
        return Video.size
    }
    
    private func getEstimatedVideoFileSize(for asset: AVAsset) async -> Double? {
        guard let exportSession = getAVAssetExportSession(
            from: asset,
            outputURL: FileManager.default.temporaryDirectory
        ) else {
            DDLogError("No export asset for the video available")
            return nil
        }
        
        return try? await Double(integerLiteral: exportSession.estimatedOutputFileLengthInBytes)
    }
            
    @objc func getAVAssetExportSession(from asset: AVAsset, outputURL: URL) -> AVAssetExportSession? {
        guard asset.tracks(withMediaType: .video).first != nil else {
            DDLogError("No video track found")
            return nil
        }
        
        let sortedPresetNames =
            switch videoQualitySetting {
            case .low:
                [AVAssetExportPresetLowQuality]
            case .high:
                [
                    AVAssetExportPresetMediumQuality,
                    AVAssetExportPresetLowQuality,
                ]
            case .original:
                if AppGroup.getCurrentType() == AppGroupTypeApp {
                    [
                        AVAssetExportPresetPassthrough,
                        AVAssetExportPresetHighestQuality,
                        AVAssetExportPresetMediumQuality,
                        AVAssetExportPresetLowQuality,
                    ]
                }
                else {
                    [
                        AVAssetExportPresetMediumQuality,
                        AVAssetExportPresetLowQuality,
                    ]
                }
            }
                
        var exportSession: AVAssetExportSession? = nil
        
        for presetName in sortedPresetNames {
            if exportSession != nil {
                break
            }

            let tmpSession = createExportSession(
                presetName: presetName,
                asset: asset,
                outputURL: outputURL
            )

            let group = DispatchGroup()
            group.enter()

            tmpSession?.estimateOutputFileLength(completionHandler: { estimatedSize, _ in
                if estimatedSize > 0, estimatedSize <= kMaxFileSize {
                    exportSession = tmpSession
                }
                group.leave()
            })
            
            group.wait()
        }
        
        return exportSession
    }

    // MARK: Private Properties
            
    private var videoQualitySetting: VideoQualitySetting {
        guard let videoQualitySettingsString = userSettings.videoQuality else {
            return .high
        }
        
        switch videoQualitySettingsString {
        case "low": return .low
        case "high": return .high
        case "original": return .original
        default: return .low
        }
    }
    
    private func createExportSession(
        presetName: String,
        asset: AVAsset,
        outputURL: URL
    ) -> AVAssetExportSession? {
                
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: presetName) else {
            return nil
        }
                        
        exportSession.outputURL = outputURL
        exportSession.shouldOptimizeForNetworkUse = true
        let fileType: AVFileType = .mp4
        exportSession.outputFileType = fileType
        exportSession.fileLengthLimit = Int64(kMaxFileSize)
        exportSession.metadataItemFilter = .forSharing()
        
        let creationDateMetaDataItem = AVMutableMetadataItem()
        creationDateMetaDataItem.key = AVMetadataKey.commonKeyCreationDate as NSCopying & NSObjectProtocol
        creationDateMetaDataItem.keySpace = .common
        creationDateMetaDataItem.value = Date() as NSCopying & NSObjectProtocol
        exportSession.metadata = [creationDateMetaDataItem]

        return exportSession
    }
}
