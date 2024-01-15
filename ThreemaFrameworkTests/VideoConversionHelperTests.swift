//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
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
import XCTest
@testable import ThreemaFramework

class VideoConversationHelperTests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testBitrateDoesNotIncrease() throws {
        let originalVideoBitrate = 100
        let originalAudioBitrate = 100
        let originalAudioChannels = 2
        let duration = 5
        let videoSize = 10
        let qualitySetting = VideoConversionHelper.VideoQualitySetting.high
        
        let newBitrate = VideoConversionHelper.getHighestPossibleBitrate(
            userChosenQuality: qualitySetting,
            duration: duration,
            audioBitrate: originalAudioBitrate,
            audioChannels: originalAudioChannels,
            videoBitrate: originalVideoBitrate,
            videoSize: videoSize
        )
        
        XCTAssertEqual(originalVideoBitrate, Int(newBitrate!.videoRate))
    }
    
    func testChooseMedium() throws {
        let originalVideoBitrate = 1_500_000
        let originalAudioBitrate = 1_500_000
        let originalAudioChannels = 2
        let duration = 5 * 60
        let videoSize = 1920
        let qualitySetting = VideoConversionHelper.VideoQualitySetting.high
        
        guard let newBitrate = VideoConversionHelper.getHighestPossibleBitrate(
            userChosenQuality: qualitySetting,
            duration: duration,
            audioBitrate: originalAudioBitrate,
            audioChannels: originalAudioChannels,
            videoBitrate: originalVideoBitrate,
            videoSize: videoSize
        ) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(newBitrate.videoRate, VideoConversionHelper.movieRateMedium.videoRate)
    }
    
    func testChooseLow() throws {
        let originalVideoBitrate = 1_500_000
        let originalAudioBitrate = 1_500_000
        let originalAudioChannels = 2
        let duration = 10 * 60
        let videoSize = 1920
        let qualitySetting = VideoConversionHelper.VideoQualitySetting.high
        
        print(
            VideoConversionHelper
                .getMaxdurationInMinutes(
                    videoBitrate: Int64(kVideoBitrateMedium),
                    audioBitrate: Int64(kAudioBitrateMedium)
                )
        )
        
        guard let newBitrate = VideoConversionHelper.getHighestPossibleBitrate(
            userChosenQuality: qualitySetting,
            duration: duration,
            audioBitrate: originalAudioBitrate,
            audioChannels: originalAudioChannels,
            videoBitrate: originalVideoBitrate,
            videoSize: videoSize
        ) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(newBitrate.videoRate, VideoConversionHelper.movieRateLow.videoRate)
    }
    
    func testIntegrityStillAllowed() throws {
        let originalVideoBitrate: Int64 = 250_000
        let originalAudioChannels = 1
        let originalAudioBitrate: Int64 = 50000
        let videoSize: Int32 = 500
        
        let duration = VideoConversionHelper.getMaxdurationInMinutes(
            videoBitrate: originalVideoBitrate,
            audioBitrate: originalAudioBitrate
        ) * 60
        
        guard let newBitrate = VideoConversionHelper.getHighestPossibleBitrate(
            userChosenQuality: VideoConversionHelper.VideoQualitySetting.original,
            duration: Int(duration),
            audioBitrate: Int(originalAudioBitrate),
            audioChannels: originalAudioChannels,
            videoBitrate: Int(originalVideoBitrate),
            videoSize: Int(videoSize)
        ) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(Int64(newBitrate.videoRate), originalVideoBitrate)
    }
    
    func testIntegrityNotAllowedAnymore() throws {
        let originalVideoBitrate: Int64 = 250_000
        let originalAudioBitrate: Int64 = 50000
        let originalAudioChannels = 2
        let videoSize: Int32 = 500
        
        let duration = VideoConversionHelper.getMaxdurationInMinutes(
            videoBitrate: originalVideoBitrate,
            audioBitrate: originalAudioBitrate
        ) * 60 + 60
        
        let newBitrate = VideoConversionHelper.getHighestPossibleBitrate(
            userChosenQuality: VideoConversionHelper.VideoQualitySetting.original,
            duration: Int(duration),
            audioBitrate: Int(originalAudioBitrate),
            audioChannels: 2,
            videoBitrate: Int(originalVideoBitrate),
            videoSize: Int(videoSize)
        )
        
        XCTAssertNil(newBitrate)
    }
}
