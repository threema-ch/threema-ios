import Foundation
import XCTest
@testable import ThreemaFramework

final class VideoConversationHelperTests: XCTestCase {

    func testGetEstimatedVideoFileSize() throws {
        let testBundle = Bundle(for: VideoConversationHelperTests.self)
        let testVideoURL = try XCTUnwrap(testBundle.url(forResource: "Video-1", withExtension: "mp4"))

        let userSettingsMock = UserSettingsMock(videoQuality: "original")
        let videoConversionHelper = makeSUT(userSettings: userSettingsMock)

        let size = try XCTUnwrap(videoConversionHelper.getEstimatedVideoFileSize(for: testVideoURL))

        XCTAssertEqual(30_134_549.0, size)
    }

    func testVideoQualityOriginal() async throws {
        let testBundle = Bundle(for: VideoConversationHelperTests.self)
        let testVideoURL = try XCTUnwrap(testBundle.url(forResource: "Video-1", withExtension: "mp4"))
        let asset = AVAsset(url: testVideoURL)
        
        let userSettingsMock = UserSettingsMock(videoQuality: "original")
        let videoConversionHelper = makeSUT(userSettings: userSettingsMock)

        let exportSession = await videoConversionHelper.getAVAssetExportSession(
            from: asset,
            outputURL: FileManager.default.temporaryDirectory
        )
        
        XCTAssertEqual(exportSession?.presetName, "AVAssetExportPresetPassthrough")
    }
    
    func testVideoQualityLow() async throws {
        let testBundle = Bundle(for: VideoConversationHelperTests.self)
        let testVideoURL = try XCTUnwrap(testBundle.url(forResource: "Video-1", withExtension: "mp4"))
        let asset = AVAsset(url: testVideoURL)
        
        let userSettingsMock = UserSettingsMock(videoQuality: "low")
        let videoConversionHelper = makeSUT(userSettings: userSettingsMock)

        let exportSession = await videoConversionHelper.getAVAssetExportSession(
            from: asset,
            outputURL: FileManager.default.temporaryDirectory
        )
        
        XCTAssertEqual(exportSession?.presetName, "AVAssetExportPresetLowQuality")
    }
    
    func testVideoQualityHigh() async throws {
        let testBundle = Bundle(for: VideoConversationHelperTests.self)
        let testVideoURL = try XCTUnwrap(testBundle.url(forResource: "Video-1", withExtension: "mp4"))
        let asset = AVAsset(url: testVideoURL)
        
        let userSettingsMock = UserSettingsMock(videoQuality: "high")
        let videoConversionHelper = makeSUT(userSettings: userSettingsMock)

        let exportSession = await videoConversionHelper.getAVAssetExportSession(
            from: asset,
            outputURL: FileManager.default.temporaryDirectory
        )
        
        XCTAssertEqual(exportSession?.presetName, "AVAssetExportPresetMediumQuality")
    }
    
    // MARK: - Helpers
    
    private func makeSUT(
        userSettings: UserSettingsProtocol,
        outputDirectoryURL: URL = FileManager.default.temporaryDirectory
    ) -> VideoConversionHelper {
        VideoConversionHelper(
            userSettings: userSettings,
            outputDirectoryURL: outputDirectoryURL
        )
    }
}
