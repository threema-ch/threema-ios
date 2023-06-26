//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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

@objc public class VideoConversionHelper: NSObject {
    
    // MARK: - Internal Nested Types
    
    /// Internal for easier testing
    enum VideoQualitySetting {
        case low
        case high
        case original
    }
    
    /// Internal for easier testing
    struct MovieRate {
        var videoRate: Int32
        var videoSize: Int32
        var videoColorPrimariesKey: String
        var videoTransferFunctionKey: String
        var videoYCbCrMatrixKey: String
        var audioRate: Int32
        var audioChannels: Int32
        var isOriginal = false
    }
    
    // MARK: Private Properties
    
    /// Estimated file overhead for the video (same as in Android)
    /// Use for estimating final file size of the video
    private static let fileOverhead: Int64 = 48 * 1024
    
    /// Internal for easier testing
    static let movieRateHigh = MovieRate(
        videoRate: kVideoBitrateHigh,
        videoSize: kMaxVideoSizeHigh,
        videoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
        videoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
        videoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        audioRate: kAudioBitrateHigh,
        audioChannels: kAudioChannelsHigh
    )
    
    /// Internal for easier testing
    static let movieRateMedium = MovieRate(
        videoRate: kVideoBitrateMedium,
        videoSize: kMaxVideoSizeHigh,
        videoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
        videoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
        videoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        audioRate: kAudioBitrateMedium,
        audioChannels: kAudioChannelsHigh
    )
    
    /// Internal for easier testing
    static let movieRateLow = MovieRate(
        videoRate: kVideoBitrateLow,
        videoSize: kMaxVideoSizeLow,
        videoColorPrimariesKey: AVVideoColorPrimaries_SMPTE_C,
        videoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
        videoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_601_4,
        audioRate: kAudioBitrateLow,
        audioChannels: kAudioChannelsLow
    )
    
    // Must be sorted from highest to lowest bit rate
    private static let rates = [movieRateHigh, movieRateMedium, movieRateLow]
    
    private static var videoQualitySetting: VideoQualitySetting {
        guard let videoQualitySettingsString = UserSettings.shared()?.videoQuality else {
            return .high
        }
        
        switch videoQualitySettingsString {
        case "low": return .low
        case "high": return .high
        case "original": return .original
        default: return .low
        }
    }
    
    /// Return values must be ordered from highest to lowest
    static var possibleRatesForUserSetting: [MovieRate] {
        switch VideoConversionHelper.videoQualitySetting {
        case .low: return [movieRateLow]
        case .high: return [movieRateMedium, movieRateLow]
        case .original: return [movieRateHigh, movieRateMedium, movieRateLow]
        }
    }
    
    // MARK: - Functions
    
    @objc public static func videoHasAllowedSize(at url: URL) -> Bool {
        let asset = AVURLAsset(url: url)
        
        return maybeGetMovieRate(for: asset) != nil
    }
    
    public static func getEstimatedVideoFileSize(for url: URL) -> Double? {
        let asset = AVURLAsset(url: url)
        
        return getEstimatedVideoFileSize(for: asset)
    }
    
    public static func getEstimatedVideoFileSize(for asset: AVAsset) -> Double? {
        guard let rate = maybeGetMovieRate(for: asset) else {
            return nil
        }
        let duration = asset.duration.seconds
        return Double(estimatedFileSize(for: rate, with: Int64(duration)))
    }
    
    private static func estimatedFileSize(for rate: MovieRate, with duration: Int64) -> Int64 {
        let totAudioRate = Int64((rate.audioRate * rate.audioChannels) / 8)
        let totVideoRate = Int64(rate.videoRate / 8)
        let estimatedFileSize = (totVideoRate + totAudioRate) * duration + fileOverhead
        
        return estimatedFileSize
    }
    
    private static func maybeGetMovieRate(for asset: AVAsset) -> MovieRate? {
        let duration = Int(asset.duration.seconds)
        
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            return nil
        }
        
        let audioTrack = asset.tracks(withMediaType: .audio).first
        
        let videoRate = Int(videoTrack.estimatedDataRate)
        let srcVideoSize = __CGSizeApplyAffineTransform(videoTrack.naturalSize, videoTrack.preferredTransform)
        let videoSize = Int(max(srcVideoSize.height, srcVideoSize.width))
        
        var audioRate = 0
        
        if let audioTrack {
            audioRate = Int(audioTrack.estimatedDataRate)
        }
        
        var audioTrackChannels: UInt32 = 1
        if let audioTrackDescription = audioTrack?.formatDescriptions.first,
           let description =
           CMAudioFormatDescriptionGetStreamBasicDescription(audioTrackDescription as! CMAudioFormatDescription) {
            audioTrackChannels = description.pointee.mChannelsPerFrame
        }
        
        return VideoConversionHelper.getHighestPossibleBitrate(
            duration: duration,
            audioBitrate: audioRate,
            audioChannels: Int(audioTrackChannels),
            videoBitrate: videoRate,
            videoSize: videoSize
        )
    }
    
    /// Calculates the maximum duration of a video with the given audio and video bit rates in minutes
    /// - Parameters:
    ///   - videoBitrate:
    ///   - audioBitrate:
    /// - Returns: The maximum duration of a video with the given audio and video bit rates in minutes
    @objc public static func getMaxdurationInMinutes(videoBitrate: Int64, audioBitrate: Int64) -> Int64 {
        let maxFileSizeInBits = Int64(kMaxFileSize * 8)
        return (maxFileSizeInBits - fileOverhead) / ((videoBitrate + audioBitrate) * 60)
    }
    
    @objc public static func getAVAssetExportSession(from asset: AVAsset, outputURL: URL) -> SDAVAssetExportSession? {
        
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            return nil
        }
        let audioTrack = asset.tracks(withMediaType: .audio).first
        let audioTrackRate = audioTrack?.estimatedDataRate ?? 0
        var audioTrackChannels: UInt32 = 1
        if let audioTrackDescription = audioTrack?.formatDescriptions.first,
           let description =
           CMAudioFormatDescriptionGetStreamBasicDescription(audioTrackDescription as! CMAudioFormatDescription) {
            audioTrackChannels = description.pointee.mChannelsPerFrame
        }
        
        var srcVideoSize = __CGSizeApplyAffineTransform(videoTrack.naturalSize, videoTrack.preferredTransform)
        let videoSize = Int(max(srcVideoSize.height, srcVideoSize.width))
        
        if srcVideoSize.width < 0 {
            srcVideoSize.width = -srcVideoSize.width
        }
        
        if srcVideoSize.height < 0 {
            srcVideoSize.height = -srcVideoSize.height
        }
        
        let duration = Int(asset.duration.seconds)
        guard let rate = VideoConversionHelper.getHighestPossibleBitrate(
            duration: duration,
            audioBitrate: Int(audioTrackRate),
            audioChannels: Int(audioTrackChannels),
            videoBitrate: Int(
                videoTrack
                    .estimatedDataRate
            ),
            videoSize: videoSize
        ) else {
            return nil
        }
        
        var targetVideoSize: CGSize = srcVideoSize
        if targetVideoSize.width > CGFloat(rate.videoSize) {
            targetVideoSize.height *= (CGFloat(rate.videoSize) / targetVideoSize.width)
            targetVideoSize.width = CGFloat(rate.videoSize)
        }
        if targetVideoSize.height > CGFloat(rate.videoSize) {
            targetVideoSize.width *= (CGFloat(rate.videoSize) / targetVideoSize.height)
            targetVideoSize.height = CGFloat(rate.videoSize)
        }
        
        let videoWidth = roundf(Float(targetVideoSize.width / 16.0)) * 16
        let videoHeight = roundf(Float(targetVideoSize.height / 16.0)) * 16
        
        // We check for certain values to be higher than 0. otherwise the AVAssetWriter crashes during export.
        guard videoWidth > 0 else {
            DDLogError("[VideoConversionHelper] Video width was less than 0.")
            return nil
        }
        
        guard videoHeight > 0 else {
            DDLogError("[VideoConversionHelper] Video height was less than 0.")
            return nil
        }
        
        guard rate.videoRate > 0 else {
            DDLogError("[VideoConversionHelper] VideoRate was less than 0.")
            return nil
        }
        
        guard let exportSession = SDAVAssetExportSession(asset: asset) else {
            return nil
        }
        
        // Video conversation fails if the 3.1 profile was chosen for a video bigger than 720p. We suspect that this is
        // because of the contradictory video size information but couldn't conform this.
        // The error code given was error -12900 without any message
        let profileLevelKey = rate
            .isOriginal ? AVVideoProfileLevelH264BaselineAutoLevel : AVVideoProfileLevelH264Baseline31
        
        exportSession.outputURL = outputURL
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.outputFileType = AVFileType.mp4.rawValue
        
        exportSession.videoSettings = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: NSNumber(value: videoWidth),
            AVVideoHeightKey: NSNumber(value: videoHeight),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: rate.videoRate,
                AVVideoProfileLevelKey: profileLevelKey,
                AVVideoColorPrimariesKey: rate.videoColorPrimariesKey,
                AVVideoTransferFunctionKey: rate.videoTransferFunctionKey,
                AVVideoYCbCrMatrixKey: rate.videoYCbCrMatrixKey,
            ],
        ]
        
        exportSession.audioSettings = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: rate.audioChannels,
            AVSampleRateKey: 44100,
            AVEncoderBitRatePerChannelKey: rate.audioRate,
        ]
        
        return exportSession
    }
    
    // MARK: - Helper Functions
    
    /// Respecting the user settings returns the highest possible bitrate for a video of duration `d` with given audio
    /// and video bitrates or nil if the video cannot fit within the global file size limit.
    /// - Parameters:
    ///   - duration: Duration of the video in seconds
    ///   - audioBitrate: original estimated audio bitrate of the video
    ///   - videoBitrate: original estimated video bitrate of the video
    ///   - videoSize: original video size in pixels
    /// - Returns: The highest possible video bitrate which fits in the global file size limit or the maximum allowed by
    ///            the user or nil if
    /// the video cannot fit into the global file size limit.
    private static func getHighestPossibleBitrate(
        duration: Int,
        audioBitrate: Int,
        audioChannels: Int,
        videoBitrate: Int,
        videoSize: Int
    ) -> MovieRate? {
        getHighestPossibleBitrate(
            userChosenQuality: VideoConversionHelper.videoQualitySetting,
            duration: duration,
            audioBitrate: audioBitrate,
            audioChannels: audioChannels,
            videoBitrate: videoBitrate,
            videoSize: videoSize
        )
    }
    
    /// See `getHighestPossibleBitrate` above for more information
    /// Only marked as `internal` for testing.
    static func getHighestPossibleBitrate(
        userChosenQuality: VideoQualitySetting,
        duration: Int,
        audioBitrate: Int,
        audioChannels: Int,
        videoBitrate: Int,
        videoSize: Int
    ) -> MovieRate? {
        
        if UserSettings.shared()?.videoQuality == "low" {
            return rates.last
        }
        
        // There seems to be a minimum value of 32k and a maximum of 160k for AVEncoderBitRateKey
        let audioBitrate = min(max(Int(movieRateLow.audioRate), audioBitrate), 160 * 1000)
        
        let originalSize = Int((videoBitrate + audioBitrate * audioChannels) / 8) * duration
        
        let userChosenMovieRate = VideoConversionHelper.possibleRatesForUserSetting.first!
        
        // If it is possible to send the video in its original bitrate and the user has chosen original we choose the
        // original bitrate
        // If the user configured bitrate is higher than the one used in the video and the video fits in the max file
        // size we also use the original bit rate to avoid increasing video file size
        if originalSize <= kMaxFileSize,
           VideoConversionHelper.videoQualitySetting == .original ||
           (userChosenMovieRate.videoRate > videoBitrate && userChosenMovieRate.audioRate > audioBitrate) {
            return MovieRate(
                videoRate: Int32(videoBitrate),
                videoSize: Int32(videoSize),
                videoColorPrimariesKey: movieRateHigh.videoColorPrimariesKey,
                videoTransferFunctionKey: movieRateHigh.videoTransferFunctionKey,
                videoYCbCrMatrixKey: movieRateHigh.videoYCbCrMatrixKey,
                audioRate: Int32(audioBitrate),
                audioChannels: Int32(audioChannels),
                isOriginal: true
            )
        }
        
        // Get the highest possible rate while still respecting the user settings
        for rate in VideoConversionHelper.possibleRatesForUserSetting {
            let totAudioRate = (rate.audioRate * rate.audioChannels) / 8
            let totVideoRate = rate.videoRate / 8
            let fileSize = Int(totVideoRate + totAudioRate) * duration
            if fileSize <= kMaxFileSize {
                return rate
            }
        }
        
        // Return nil if nothing fits
        return nil
    }
}
