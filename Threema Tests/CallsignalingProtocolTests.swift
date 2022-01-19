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

import XCTest

@testable import ThreemaFramework

class CallsignalingProtocolTests: XCTestCase {
    
    /**
     * Helper class.
     */
    
    struct Pair {
        let a: CallsignalingProtocol.ThreemaVideoCallQualityProfiles
        let b: CallsignalingProtocol.ThreemaVideoCallQualityProfiles
    }
    
    func testSerializeProfile() throws {
        // Create a high quality profile
        let highProfile = CallsignalingProtocol.ThreemaVideoCallQualityProfiles.high
        
        // Serialize to protobuf
        guard let bytes: Data = CallsignalingProtocol.encodeVideoQuality(highProfile) else {
            XCTFail("quality profile bytes are empty")
            return
        }
        
        // Deserialize
        guard let envelop: Callsignaling_Envelope = try? Callsignaling_Envelope(serializedData: bytes) else {
            XCTFail("envelope is nil")
            return
        }
        
        var hasQualityProfile = false
        switch envelop.content {
        case .videoQualityProfile(envelop.videoQualityProfile):
            hasQualityProfile = true
            break
        default: break
        }
                
        XCTAssertTrue(hasQualityProfile)
        
        let profile = envelop.videoQualityProfile
        XCTAssertTrue(profile.hasMaxResolution)
        XCTAssertEqual(Callsignaling_VideoQualityProfile.QualityProfile.high, profile.profile)
        XCTAssertEqual(2000, profile.maxBitrateKbps)
        XCTAssertEqual(25, profile.maxFps)
        XCTAssertEqual(1280, profile.maxResolution.width)
        XCTAssertEqual(720, profile.maxResolution.height)
    }
    
    func testFindCommonProfileLow() throws {
        let pairs = [Pair.init(a: .low, b: .low),
                     Pair.init(a: .low, b: .high),
                     Pair.init(a: .low, b: .max),
                     Pair.init(a: .high, b: .low),
                     Pair.init(a: .max, b: .low)]
        
        for pair in pairs {
            let common = CallsignalingProtocol.findCommonProfile(remoteProfile: pair.a.qualityProfile(), networkIsRelayed: false, pair.b.qualityProfile())
            XCTAssertEqual(.low, common.profile)
        }
    }
    
    func testFindCommonProfileHigh() throws {
        let pairs = [Pair.init(a: .high, b: .high),
                     Pair.init(a: .high, b: .max),
                     Pair.init(a: .max, b: .high)]
        for pair in pairs {
            let common = CallsignalingProtocol.findCommonProfile(remoteProfile: pair.a.qualityProfile(), networkIsRelayed: false, pair.b.qualityProfile())
            XCTAssertEqual(.high, common.profile)
        }
    }
    
    func testFindCommonProfileMax() throws {
        let a: CallsignalingProtocol.ThreemaVideoCallQualityProfiles = .max
        let b: CallsignalingProtocol.ThreemaVideoCallQualityProfiles = .max
        
        let commonNonRelayed = CallsignalingProtocol.findCommonProfile(remoteProfile: a.qualityProfile(), networkIsRelayed: false, b.qualityProfile())
        let commonRelayed = CallsignalingProtocol.findCommonProfile(remoteProfile: a.qualityProfile(), networkIsRelayed: true, b.qualityProfile())
        
        XCTAssertEqual(.max, commonNonRelayed.profile)
        XCTAssertEqual(.high, commonRelayed.profile)
    }
    
    func testFindCommonProfileNil() throws {
        let params: [CallsignalingProtocol.ThreemaVideoCallQualityProfiles] = [.low, .high, .max]
        
        for param in params {
            let commonNonRelayed = CallsignalingProtocol.findCommonProfile(remoteProfile: nil, networkIsRelayed: false, param.qualityProfile())
            let commonRelayed = CallsignalingProtocol.findCommonProfile(remoteProfile: nil, networkIsRelayed: true, param.qualityProfile())
            
            XCTAssertEqual(param, commonNonRelayed.profile)
            XCTAssertEqual(param, commonRelayed.profile)
        }
    }
    
    func testFindCommonProfileRawValues() throws {
        let a = CallsignalingProtocol.ThreemaVideoCallQualityProfile.init(bitrate: 600, maxResolution: CGSize(width: 2000, height: 700), maxFps: 23, profile: CallsignalingProtocol.ThreemaVideoCallQualityProfiles.init(rawValue: 1234) ?? nil)
        let b: CallsignalingProtocol.ThreemaVideoCallQualityProfiles = .high

        XCTAssertNotNil(a)

        let common = CallsignalingProtocol.findCommonProfile(remoteProfile: a, networkIsRelayed: false, b.qualityProfile())
        XCTAssertNil(common.profile)
        XCTAssertEqual(600, common.bitrate)
        XCTAssertEqual(23, common.maxFps)
        XCTAssertEqual(1280, common.maxResolution.width)
        XCTAssertEqual(700, common.maxResolution.height)
    }

    func testFindCommonProfileRawValuesWithClamping() throws {
        let a = CallsignalingProtocol.ThreemaVideoCallQualityProfile.init(bitrate: 1, maxResolution: CGSize(width: 1, height: 1), maxFps: 1, profile: CallsignalingProtocol.ThreemaVideoCallQualityProfiles.init(rawValue: 1234) ?? nil)
        let b: CallsignalingProtocol.ThreemaVideoCallQualityProfiles = .high
        
        XCTAssertNotNil(a)

        let common = CallsignalingProtocol.findCommonProfile(remoteProfile: a, networkIsRelayed: false, b.qualityProfile())
        XCTAssertNil(common.profile)
        XCTAssertEqual(CallsignalingProtocol.minBitrate, common.bitrate)
        XCTAssertEqual(CallsignalingProtocol.minFps, common.maxFps)
        XCTAssertEqual(CallsignalingProtocol.minResolutionWidth, common.maxResolution.width)
        XCTAssertEqual(CallsignalingProtocol.minResolutionHeight, common.maxResolution.height)
    }
}
