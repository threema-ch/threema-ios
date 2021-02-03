//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2021 Threema GmbH
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
import CocoaLumberjackSwift

@objc public class VideoConversionHelper : NSObject {
    
    private static let fileOverhead : Int64 = 48 * 1024
    
    private struct MovieRate {
        var videoRate : Int32
        var videoSize : Int32
        var audioRate : Int32
        var audioChannels : Int32
    }
    
    private static let movieRateHigh = MovieRate(videoRate: kVideoBitrateHigh,
                                                 videoSize: kMaxVideoSizeHigh,
                                                 audioRate: kAudioBitrateHigh,
                                                 audioChannels: kAudioChannelsHigh)
    
    private static let movieRateMedium = MovieRate(videoRate: kVideoBitrateMedium,
                                                 videoSize: kMaxVideoSizeHigh,
                                                 audioRate: kAudioBitrateMedium,
                                                 audioChannels: kAudioChannelsHigh)
    
    private static let movieRateLow = MovieRate(videoRate: kVideoBitrateLow,
                                                 videoSize: kMaxVideoSizeLow,
                                                 audioRate: kAudioBitrateLow,
                                                 audioChannels: kAudioChannelsLow)
    
    private static let rates = [movieRateHigh, movieRateMedium, movieRateLow]
    
    private static func getHighestPossibleBitrate(duration : Int, audioBitrate : Int, videoBitrate : Int) -> MovieRate?  {
        
        if UserSettings.shared()?.videoQuality == "low" {
            return rates.last!
        }
        
        for rate in rates {
            let totAudioRate = (rate.audioRate * rate.audioChannels) / 8
            let totVideoRate = rate.videoRate / 8
            let fileSize = Int((totVideoRate + totAudioRate)) * duration
            DDLogInfo("Video File Size is \(fileSize)")
            if fileSize <= kMaxFileSize {
                return rate
            }
        }
        return nil
    }
    
    
    @objc public static func videoHasAllowedSize(at url : URL) -> Bool {
        let asset = AVURLAsset(url: url)
        
        return assetHasAllowedSize(asset: asset)
    }
    
    @objc public static func assetHasAllowedSize(asset : AVAsset) -> Bool {
        let duration : Int = Int(asset.duration.seconds)
        
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            return false
        }
        
        let audioTrack = asset.tracks(withMediaType: .audio).first
        
        let videoRate : Int = Int(videoTrack.estimatedDataRate)
        
        var audioRate : Int = 0
        
        if audioTrack != nil {
            audioRate = Int(audioTrack!.estimatedDataRate)
        }
        
        
        let bitRate = VideoConversionHelper.getHighestPossibleBitrate(duration: duration,
                                                                              audioBitrate: audioRate,
                                                                              videoBitrate: videoRate)
        
        return bitRate != nil
    }
    
    @objc public static func getMaxdurationFor(videoBitrate : Int64, audioBitrate : Int64) -> Int64 {
        return Int64(kMaxFileSize) / (videoBitrate + audioBitrate + fileOverhead)
    }
    
    @objc public static func getAVAssetExportSession(from asset : AVAsset, outputURL : URL) -> SDAVAssetExportSession? {
        
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            return nil
        }
        let audioTrackRate = asset.tracks(withMediaType: .audio).first?.estimatedDataRate ?? 0
        
        var srcVideoSize = __CGSizeApplyAffineTransform(videoTrack.naturalSize, videoTrack.preferredTransform)
        
        if srcVideoSize.width < 0 {
            srcVideoSize.width = -srcVideoSize.width
        }
        
        if srcVideoSize.height < 0 {
            srcVideoSize.height = -srcVideoSize.height
        }
        
        let duration : Int = Int(asset.duration.seconds)
        guard let rate = VideoConversionHelper.getHighestPossibleBitrate(duration: duration,
                                                                         audioBitrate: Int(audioTrackRate),
                                                                         videoBitrate: Int(videoTrack.estimatedDataRate)) else {
            return nil
        }
        
        var targetVideoSize : CGSize = srcVideoSize;
        if (targetVideoSize.width > CGFloat(rate.videoSize)) {
            targetVideoSize.height *= (CGFloat(rate.videoSize) / targetVideoSize.width);
            targetVideoSize.width = CGFloat(rate.videoSize);
        }
        if (targetVideoSize.height > CGFloat(rate.videoSize)) {
            targetVideoSize.width *= (CGFloat(rate.videoSize) / targetVideoSize.height);
            targetVideoSize.height = CGFloat(rate.videoSize);
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
            AVVideoCodecKey : AVVideoCodecH264,
            AVVideoWidthKey : NSNumber(value: videoWidth),
            AVVideoHeightKey : NSNumber(value: videoHeight),
            AVVideoCompressionPropertiesKey : [
                AVVideoAverageBitRateKey : rate.videoRate,
                AVVideoProfileLevelKey : AVVideoProfileLevelH264Baseline31
            ],
        ]
        
        exportSession.audioSettings = [
            AVFormatIDKey : kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey : rate.audioChannels,
            AVSampleRateKey : 44100,
            AVEncoderBitRateKey : rate.audioRate
        ]
        
        return exportSession
    }
}
