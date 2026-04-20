import CocoaLumberjackSwift
import FileUtility
import Foundation

final class VideoConversionHelper: NSObject {
    private let userSettings: UserSettingsProtocol
    private let outputDirectoryURL: URL

    // MARK: - Internal Nested Types
    
    enum VideoQualitySetting {
        case low
        case high
        case original
    }
    
    #if DEBUG
        init(
            userSettings: UserSettingsProtocol,
            outputDirectoryURL: URL
        ) {
            self.userSettings = userSettings
            self.outputDirectoryURL = outputDirectoryURL
        }
    #endif
    
    @objc override init() {
        self.userSettings = UserSettings.shared()
        self.outputDirectoryURL = FileUtility.shared.appTemporaryDirectory
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

    func getAVAssetExportSession(from asset: AVAsset, outputURL: URL) async -> AVAssetExportSession? {
        guard await (try? asset.loadTracks(withMediaType: .video))?.first != nil else {
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

        for preset in sortedPresetNames {
            guard let session = createExportSession(presetName: preset, asset: asset, outputURL: outputURL) else {
                continue
            }

            do {
                let estimatedSize = try await session.estimatedOutputFileLengthInBytes
                if estimatedSize > 0, estimatedSize <= kMaxFileSize {
                    return session
                }
            }
            catch {
                // Trying next preset
                continue
            }
        }

        return nil
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

    private func getEstimatedVideoFileSize(for asset: AVAsset) async -> Double? {
        guard let exportSession = await getAVAssetExportSession(
            from: asset,
            outputURL: outputDirectoryURL
        ) else {
            DDLogError("No export asset for the video available")
            return nil
        }

        return try? await Double(integerLiteral: exportSession.estimatedOutputFileLengthInBytes)
    }
}
