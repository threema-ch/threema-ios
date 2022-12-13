//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2022 Threema GmbH
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
    
    private static let fileOverhead: Int64 = 48 * 1024
    
    private struct MovieRate {
        var videoRate: Int32
        var videoSize: Int32
        var videoColorPrimariesKey: String
        var videoTransferFunctionKey: String
        var videoYCbCrMatrixKey: String
        var audioRate: Int32
        var audioChannels: Int32
    }
    
    private static let movieRateHigh = MovieRate(
        videoRate: kVideoBitrateHigh,
        videoSize: kMaxVideoSizeHigh,
        videoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
        videoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
        videoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        audioRate: kAudioBitrateHigh,
        audioChannels: kAudioChannelsHigh
    )
    
    private static let movieRateMedium = MovieRate(
        videoRate: kVideoBitrateMedium,
        videoSize: kMaxVideoSizeHigh,
        videoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
        videoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
        videoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        audioRate: kAudioBitrateMedium,
        audioChannels: kAudioChannelsHigh
    )
    
    private static let movieRateLow = MovieRate(
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
    
    private static func getHighestPossibleBitrate(
        duration: Int,
        audioBitrate: Int,
        videoBitrate: Int,
        videoSize: Int
    ) -> MovieRate? {
        
        if UserSettings.shared()?.videoQuality == "low" {
            return rates.last
        }
        
        let originalSize = Int((videoBitrate + audioBitrate) / 8) * duration
        
        // Filter all bitrates resulting in a larger file.
        let possibleRates = rates
            .filter { Int(($0.videoRate + $0.audioRate * $0.audioChannels) / 8) * duration <= originalSize }
        
        // If the original size is smaller than our lowest rate, choose the original rate.
        if possibleRates.isEmpty, originalSize <= kMaxFileSize {
            return MovieRate(
                videoRate: Int32(videoBitrate),
                videoSize: Int32(videoSize),
                videoColorPrimariesKey: movieRateLow.videoColorPrimariesKey,
                videoTransferFunctionKey: movieRateLow.videoTransferFunctionKey,
                videoYCbCrMatrixKey: movieRateLow.videoYCbCrMatrixKey,
                audioRate: Int32(audioBitrate),
                audioChannels: 1
            )
        }
        
        for rate in possibleRates {
            let fileSize = Int(VideoConversionHelper.estimatedFileSize(for: rate, with: Int64(duration)))
            DDLogVerbose("Video File Size is \(fileSize)")
            if fileSize <= kMaxFileSize {
                return rate
            }
        }
        return nil
    }
    
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
        
        if audioTrack != nil {
            audioRate = Int(audioTrack!.estimatedDataRate)
        }
        
        return VideoConversionHelper.getHighestPossibleBitrate(
            duration: duration,
            audioBitrate: audioRate,
            videoBitrate: videoRate,
            videoSize: videoSize
        )
    }
    
    @objc public static func getMaxdurationFor(videoBitrate: Int64, audioBitrate: Int64) -> Int64 {
        Int64(kMaxFileSize) / (videoBitrate + audioBitrate + fileOverhead)
    }
    
    @objc public static func getAVAssetExportSession(from asset: AVAsset, outputURL: URL) -> SDAVAssetExportSession? {
        
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            return nil
        }
        let audioTrackRate = asset.tracks(withMediaType: .audio).first?.estimatedDataRate ?? 0
        
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
        
        guard let exportSession = SDAVAssetExportSession(asset: asset) else {
            return nil
        }
        
        exportSession.outputURL = outputURL
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.outputFileType = AVFileType.mp4.rawValue
        
        exportSession.videoSettings = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: NSNumber(value: videoWidth),
            AVVideoHeightKey: NSNumber(value: videoHeight),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: rate.videoRate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264Baseline31,
                AVVideoColorPrimariesKey: rate.videoColorPrimariesKey,
                AVVideoTransferFunctionKey: rate.videoTransferFunctionKey,
                AVVideoYCbCrMatrixKey: rate.videoYCbCrMatrixKey,
            ],
        ]
        
        exportSession.audioSettings = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: rate.audioChannels,
            AVSampleRateKey: 44100,
            AVEncoderBitRateKey: rate.audioRate,
        ]
        
        return exportSession
    }
}
