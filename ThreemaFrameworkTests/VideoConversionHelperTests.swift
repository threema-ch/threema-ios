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

    func testGetEstimatedVideoFileSize() throws {
        let testBundle = Bundle(for: VideoConversationHelperTests.self)
        let testVideoURL = try XCTUnwrap(testBundle.url(forResource: "Video-1", withExtension: "mp4"))

        let userSettingsMock = UserSettingsMock(videoQuality: "original")
        let videoConversionHelper = VideoConversionHelper(userSettings: userSettingsMock)

        let size = try XCTUnwrap(videoConversionHelper.getEstimatedVideoFileSize(for: testVideoURL))

        XCTAssertEqual(30_134_549.0, size)
    }

    func testVideoQualityOriginal() throws {
        let testBundle = Bundle(for: VideoConversationHelperTests.self)
        let testVideoURL = try XCTUnwrap(testBundle.url(forResource: "Video-1", withExtension: "mp4"))
        let asset = AVAsset(url: testVideoURL)
        
        let userSettingsMock = UserSettingsMock(videoQuality: "original")
        let videoConversionHelper = VideoConversionHelper(userSettings: userSettingsMock)

        let exportSession = videoConversionHelper.getAVAssetExportSession(
            from: asset,
            outputURL: FileManager.default.temporaryDirectory
        )
        
        XCTAssertEqual(exportSession?.presetName, "AVAssetExportPresetPassthrough")
    }
    
    func testVideoQualityLow() throws {
        let testBundle = Bundle(for: VideoConversationHelperTests.self)
        let testVideoURL = try XCTUnwrap(testBundle.url(forResource: "Video-1", withExtension: "mp4"))
        let asset = AVAsset(url: testVideoURL)
        
        let userSettingsMock = UserSettingsMock(videoQuality: "low")
        let videoConversionHelper = VideoConversionHelper(userSettings: userSettingsMock)

        let exportSession = videoConversionHelper.getAVAssetExportSession(
            from: asset,
            outputURL: FileManager.default.temporaryDirectory
        )
        
        XCTAssertEqual(exportSession?.presetName, "AVAssetExportPresetLowQuality")
    }
    
    func testVideoQualityHigh() throws {
        let testBundle = Bundle(for: VideoConversationHelperTests.self)
        let testVideoURL = try XCTUnwrap(testBundle.url(forResource: "Video-1", withExtension: "mp4"))
        let asset = AVAsset(url: testVideoURL)
        
        let userSettingsMock = UserSettingsMock(videoQuality: "high")
        let videoConversionHelper = VideoConversionHelper(userSettings: userSettingsMock)

        let exportSession = videoConversionHelper.getAVAssetExportSession(
            from: asset,
            outputURL: FileManager.default.temporaryDirectory
        )
        
        XCTAssertEqual(exportSession?.presetName, "AVAssetExportPresetMediumQuality")
    }
}
